const hre = require("hardhat");
const fs = require("fs");
const { promisify } = require('util');
const path = require('path');

const { abi: ERC20ABI } = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");
const { abi: FlashABI } = require("../artifacts/contracts/FlashTri.sol/ContractFlashTri.json");

const readFileAsync = promisify(fs.readFile)
const writeFileAsync = promisify(fs.writeFile)

require("dotenv").config();

let
 config,
 arb,
 owner,
 inTrade,
 balances;

const network = hre.network.name;
let configPath = '';
if (network === 'polygon') {configPath = '../config/polygon.json'; config = require(configPath);}
if (network === 'bTestnet') {configPath = '../config/bTestnet.json'; config = require(configPath);}

console.log(`loaded config`);

// 0x604229c960e5CACF2aaEAc8Be68Ac07BA9dF81c3

const main = async () => {
  await setup();
}


// Addresses
const deployedAddress = "0x5B7ff4E29697ebed11eE4c10B04307cCEe7f6742"; // DEPLOYED CONTRACT
const factoryPancake = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
const routerPancake = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const tokenA = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
const tokenB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
const tokenC = "0x89675DcCFE0c19bca178A0E0384Bd8E273a45cbA";

// Inputs
const factories = [factoryPancake, factoryPancake, factoryPancake];
const routers = [routerPancake, routerPancake, routerPancake];
const tokens = [tokenA, tokenB, tokenC];
const borrowAmount = 100000000;
console.log(borrowAmount.toString());


// lend me token A then try swapping it for sec then try swapping that for base2 then base2 to pay back A
// const arbTx = await contractFlashSwap.triangularArbitrage(
//   factories,
//   routers,
//   tokens,
//   borrowAmount,
//   {
//     gasLimit: 6000000,
//     gasPrice: ethers.utils.parseUnits("5.5", "gwei"),
//   }
// );
// console.log(arbTx);



// call arb on x for all available base currencies
// using secondary call arb on every base against another base looking for an innefficency eg. sec<->usdt ->> usdc/wmatic/dai
// lend me token A then try swapping all that for sec then try swapping that for base2 then base2 to pay back A

async function checkArb() {
  let factory1 = config.watchFactories["QUICKSWAP"].factory;
  let factory2 = config.watchFactories["APESWAP"].factory;
  let routers1 = config.watchFactories["QUICKSWAP"].router;
  let routers2 = config.watchFactories["APESWAP"].router;

  // think in terms of (router 1swap between tokens per dex) and not tokens to multi use tri for dual
  let dex1SwapFrom2 = config.tokens.crv.address;
  let dex2SwapFrom = config.tokens.wmatic.address;
  let dex1SwapFrom = config.tokens.usdc.address;

  try {
    let arbCheck = await arb.connect(owner).triangularArbitrage(
      [factory1, factory2, factory1],
      [routers1, routers2, routers1],
      [dex1SwapFrom, dex2SwapFrom, dex1SwapFrom2],
      borrowAmount,
      {gasPrice: ethers.utils.parseUnits("1000", "gwei")}
    );

    await arbCheck.wait();
    console.log(arbCheck);
    if(cb) cb(false);
    console.log(`arb value : ${arbCheck} for flashloan ?-> ${borrowAmount} ${config.baseCurrencies[baseToken].name} : ${config.baseCurrencies[baseToken].name} -> ${config.secondaryCurrencies[secondaryToken].name} <- ${config.baseCurrencies[base2Token].name}`)
  } catch(e) {
    setTimeout(checkArb,3000)
    if(!e.reason) console.log(e);
    if(e.reason.indexOf('Pool does not exist') > -1) {
      console.log(e.reason);
    }

    console.log(e.reason);
  }
}



const setup = async () => {
  [owner] = await ethers.getSigners();
  console.log(`Owner: ${owner.address}`);
  const IArb = await ethers.getContractFactory('ContractFlashTri');
  // const Itoken = await ethers.getContractFactory('IERC20');
  // const IPair = await ethers.getContractFactory('contracts/Arb.sol:IUniswapV2Pair');
  arb = await IArb.attach(config.arbContract);
  const quickswapFactory = await ethers.getContractAt('contracts/interfaces/IUniswapV2Factory.sol:IUniswapV2Factory', config.watchFactories["QUICKSWAP"].factory);

  // Isecondary = await ethers.getContractAt('contracts/Arb.sol:IERC20', "0xc2132D05D31c914a87C6611C10748AEb04B58e8F");
  const ERC20abi = [
    "function name() public view returns (string)",
    "function symbol() public view returns (string)",
    "function decimals() public view returns (uint8)",
    "function totalSupply() public view returns (uint256)",
    "function approve(address _spender, uint256 _value) public returns (bool success)"];



  quickswapFactory.on("PairCreated", async (token0, token1, pairAddress) => {
    // blah blah blah
  });

  checkArb();

}



// // randomly selects exchanges to see profit spread on tokens for a baseToken
// process.on('uncaughtException', function(err) {
//   console.log('UnCaught Exception 83: ' + err);
//   console.error(err.stack);
//   fs.appendFile('./critical.txt', err.stack, function(){ });
// });
//
// process.on('unhandledRejection', (reason, p) => {
//   console.log('Unhandled Rejection at: '+p+' - reason: '+reason);
// });
//
(async () => await main())();
//test
