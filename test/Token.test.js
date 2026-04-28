const Token = artifacts.require("Token");

contract("Token", (accounts) => {
    let token;
    const [owner, alice, bob] = accounts;

    beforeEach(async () => {
        token = await Token.new();
    });

    it("should mint tokens when ETH is deposited", async () => {
        const amount = web3.utils.toWei("1", "ether");
        await token.mint({ from: alice, value: amount });
        const balance = await token.balanceOf(alice);
        assert.equal(balance.toString(), amount);
    });

    it("should assign dividends proportionally", async () => {
        const amount1 = web3.utils.toWei("1", "ether");
        const amount2 = web3.utils.toWei("3", "ether");
        await token.mint({ from: alice, value: amount1 });
        await token.mint({ from: bob, value: amount2 });

        const dividend = web3.utils.toWei("4", "ether");
        await token.recordDividend({ from: owner, value: dividend });

        const divAlice = await token.getWithdrawableDividend(alice);
        const divBob = await token.getWithdrawableDividend(bob);

        // Alice should have 1/4 of 4 ETH = 1 ETH
        // Bob should have 3/4 of 4 ETH = 3 ETH
        assert.equal(divAlice.toString(), web3.utils.toWei("1", "ether"));
        assert.equal(divBob.toString(), web3.utils.toWei("3", "ether"));
    });

    it("should keep dividends after transfer", async () => {
        const amount = web3.utils.toWei("1", "ether");
        await token.mint({ from: alice, value: amount });
        
        await token.recordDividend({ from: owner, value: amount });
        
        // Alice transfers all tokens to Bob
        await token.transfer(bob, amount, { from: alice });
        
        const divAlice = await token.getWithdrawableDividend(alice);
        assert.equal(divAlice.toString(), amount, "Alice should still have her dividend");
        
        const divBob = await token.getWithdrawableDividend(bob);
        assert.equal(divBob.toString(), "0", "Bob should not have received Alice's accrued dividend");
    });

    it("should allow withdrawing dividends", async () => {
        const amount = web3.utils.toWei("1", "ether");
        await token.mint({ from: alice, value: amount });
        await token.recordDividend({ from: owner, value: amount });

        const initialBalance = BigInt(await web3.eth.getBalance(owner)); // withdraw to owner to avoid gas math for alice
        await token.withdrawDividend(owner, { from: alice });
        const finalBalance = BigInt(await web3.eth.getBalance(owner));
        
        assert.equal((finalBalance - initialBalance).toString(), amount);
    });
});
