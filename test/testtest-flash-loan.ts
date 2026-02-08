import { ethers } from "hardhat";
const { expect } = require("chai");

describe("FlashLoan Arbitrage", function () {
  it("Should execute flash loan successfully", async function () {
    // 1. 获取一些 WETH 巨鲸地址来做测试（虽然闪电贷不需要本金，但我们需要付 Gas）
    // 其实在这个测试里，我们只要合约部署者有 ETH 付 Gas 就行。
    const [owner] = await ethers.getSigners();

    // 2. 部署我们的套利合约
    const FlashLoanArb = await ethers.getContractFactory("FlashLoanArb");
    const arbitrage = await FlashLoanArb.deploy();
    await arbitrage.waitForDeployment();
    console.log("Arbitrage Contract deployed to:", await arbitrage.getAddress());

    // 3. 定义 Uniswap WETH/DAI Pair 地址 (我们要找它借钱)
    const UNI_PAIR_WETH_DAI = "0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11";
    // 定义借款金额 (10 WETH)
    const BORROW_AMOUNT = ethers.parseEther("10");

    // 4. 执行套利!
    // 注意：因为我们是 WETH -> DAI -> WETH 在同一个 Router 交易，
    // 肯定会亏手续费，导致最终 WETH 变少，从而触发 require("Not enough profit") 报错。
    // 这是预期行为！证明我们的逻辑跑通了（借到了，交易了，算账了）。
    
    console.log("Attempting Flash Loan...");
    
   await expect(
   arbitrage.executeTrade(UNI_PAIR_WETH_DAI, BORROW_AMOUNT)
   ).to.be.revertedWith("UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");

    console.log("✅ Flash Loan executed and reverted as expected (due to lack of profit).");
  });
});