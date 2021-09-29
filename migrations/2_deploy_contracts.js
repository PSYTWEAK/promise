const PromiseCore = artifacts.require("./PromiseCore.sol");
const PromiseFinder = artifacts.require("./PromiseFinder.sol");
const PromiseChef = artifacts.require("./farms/PromiseChef.sol");
const PromiseHolder = artifacts.require("./farms/PromiseHolder.sol");
const PromiseChefFinder = artifacts.require("./farms/PromiseChefFinder.sol");
const PromiseToken = artifacts.require("./token/PromiseToken.sol");
const TestToken = artifacts.require("./token/TestToken.sol");
const Helper = artifacts.require("./Helper.sol");
const WETHGateway = artifacts.require("./WETHGateway.sol");
const ShareCalulator = artifacts.require("./lib/math/ShareCalculator.sol");
const weth = "0xd0a1e359811322d97991e03f863a0c30c2cf029c";

module.exports = async function (deployer, accounts) {
  await deployer.deploy(ShareCalulator);
  await deployer.link(ShareCalulator, PromiseCore);
  await deployer.deploy(
    PromiseCore,
    "0xA7b4eD54ec0bD114D3A69bc97d9ce8CBcc09F45F"
  );

  await deployer.deploy(PromiseToken);
  await deployer.deploy(TestToken);
  const promiseCore = await PromiseCore.deployed();
  await deployer.deploy(PromiseFinder, promiseCore.address);
  const promiseFinder = await PromiseFinder.deployed();
  const promiseToken = await TestToken.deployed();

  await deployer.deploy(Helper, promiseCore.address, promiseChef.address);
  const helper = await Helper.deployed();

  await deployer.deploy(WETHGateway, promiseCore.address, weth);
  const wethGateway = await WETHGateway.deployed();
};
