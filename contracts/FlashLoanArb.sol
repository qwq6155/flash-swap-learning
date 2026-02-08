// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 定义我们需要用到的 Uniswap/Sushi 接口
interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract FlashLoanArb {
    // 资金接收者：必须是合约自己
    address private immutable owner;
    
    // 主网地址常量
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant SUSHISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    constructor() {
        owner = msg.sender;
    }

    // --- 1. 触发闪电贷的函数 ---
    // 这是我们手动调用的入口
    function executeTrade(address _pairAddress, uint _amountToBorrow) external {
        // 0. 找到我们要借的 Token (WETH) 是 token0 还是 token1
        address token0 = IUniswapV2Pair(_pairAddress).token0();
        address token1 = IUniswapV2Pair(_pairAddress).token1();
        
        uint amount0Out = _pairAddress == token0 ? _amountToBorrow : 0; // 如果 borrow 是 token0
        uint amount1Out = _pairAddress == token1 ? _amountToBorrow : 0; // 如果 borrow 是 token1

        // data 不为空，就会触发 Flash Swap 回调
        bytes memory data = abi.encode(_amountToBorrow);

        // 1. 调用 Pair 的 swap 函数，借钱！
        IUniswapV2Pair(_pairAddress).swap(amount0Out, amount1Out, address(this), data);
    }

    // --- 2. 闪电贷回调函数 ---
    // 钱借到后，Uniswap Pair 会自动调用这个函数
    // 我们必须在这里面：交易、赚钱、还钱
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        // 确认调用者是 Pair 合约（为了安全，这里简化了校验）
        
        // 2. 解码数据，拿到借款金额
        uint amountReceived = abi.decode(data, (uint));
        
        // 3. 开始套利逻辑：在 Sushiswap 上交易
        // 策略：WETH -> DAI -> WETH
        // 注意：这里为了演示，我们在同一个 Router 上买卖，实际上肯定亏钱（因为有手续费）。
        // 真实套利应该是：借 WETH -> 在 Sushi 换 DAI -> 在 Uni 换回 WETH
        
        // 3.1 授权 Sushiswap 动用我们的 WETH
        IERC20(WETH).approve(SUSHISWAP_V2_ROUTER, amountReceived);
        
        // 3.2 构造路径 WETH -> DAI
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        // 3.3 执行 Swap
        uint[] memory amounts = IUniswapV2Router(SUSHISWAP_V2_ROUTER).swapExactTokensForTokens(
            amountReceived,
            0, // 滑点设为 0 (仅测试用)
            path,
            address(this),
            block.timestamp + 120
        );
        
        uint amountDAI = amounts[1];
        
        // 3.4 马上换回来：DAI -> WETH
        IERC20(DAI).approve(SUSHISWAP_V2_ROUTER, amountDAI);
        path[0] = DAI;
        path[1] = WETH;
        
        uint[] memory amountsFinal = IUniswapV2Router(SUSHISWAP_V2_ROUTER).swapExactTokensForTokens(
            amountDAI,
            0,
            path,
            address(this),
            block.timestamp + 120
        );
        
        uint finalWETH = amountsFinal[1];

        // 4. 计算还款金额 (本金 + 0.3%)
        // Uniswap V2 手续费是 0.3%
        uint fee = (amountReceived * 3) / 997 + 1;
        uint amountToRepay = amountReceived + fee;

        // 5. 检查是否赚钱
        require(finalWETH >= amountToRepay, "Not enough profit to repay loan!");

        // 6. 还款
        IERC20(WETH).transfer(msg.sender, amountToRepay);
        
        // 7. 利润留给合约拥有者（可选）
    }
}