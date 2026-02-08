import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// 👇 引入 dotenv 配置，这行必须加！
import "dotenv/config";

// 👇 从环境变量里读取 URL
// 如果读不到（比如你忘了建 .env），就给个空字符串，防止报错崩溃
const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || "";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        // 👇 这里引用变量，而不是直接写死字符串
        url: MAINNET_RPC_URL,
        blockNumber: 19200000,
        enabled: true,
      },
      chainId: 1,
    },
  },
  mocha: {
    timeout: 300000
  }
};

export default config;