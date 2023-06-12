require("@nomiclabs/hardhat-waffle");
require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    polygon: {
      // url : `https://poly-rpc.gateway.pokt.network`,
      // url : `https://rpc.ankr.com/polygon`,
       url :  `https://polygon-rpc.com/`,
      accounts: [process.env.privateKey],
    },
    bTestnet : {
      url : `https://data-seed-prebsc-1-s3.binance.org:8545`,
      accounts: [process.env.privateKey],
    },
    aurora: {
      url: `https://mainnet.aurora.dev`,
      accounts: [process.env.privateKey],
    },
    fantom: {
      url: `https://rpc.ftm.tools/`,
      accounts: [process.env.privateKey],
    },
  },
  solidity: {
    compilers: [
      { version: "0.6.6" }     ]
  },
};
