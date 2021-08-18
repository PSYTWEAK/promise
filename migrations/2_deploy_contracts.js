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
    "0x1E67cC1199F312d495694D99C57a3667fBb6FCe5"
  );

  await deployer.deploy(PromiseToken);
  await deployer.deploy(TestToken);
  const promiseCore = await PromiseCore.deployed();
  await deployer.deploy(PromiseFinder, promiseCore.address);
  const promiseFinder = await PromiseFinder.deployed();
  const promiseToken = await TestToken.deployed();
  await deployer.deploy(
    PromiseChef,
    promiseToken.address,
    promiseCore.address,
    "1000000000000000000",
    "100",
    "30966004"
  );
  const promiseChef = await PromiseChef.deployed();
  await deployer.deploy(
    PromiseHolder,
    promiseCore.address,
    promiseChef.address
  );
  const promiseHolder = await PromiseHolder.deployed();
  await deployer.deploy(
    PromiseChefFinder,
    promiseCore.address,
    promiseChef.address,
    promiseHolder.address
  );
  const promiseChefFinder = await PromiseChefFinder.deployed();
  await promiseToken.mint(promiseChef.address, "100000000000000000000000");
  await promiseChef.setPromiseHolder(promiseHolder.address);

  let allocationPoints = "10000";
  let creatorToken = promiseToken.address;
  let joinerToken = "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619";
  let minUncalculatedRatio = ["1", "100"];
  let maxUncalculatedRatio = ["1", "70"];
  let updatePool = true;
  let expirationDate = "1634554704";
  await promiseChef.add(
    allocationPoints,
    creatorToken,
    joinerToken,
    minUncalculatedRatio,
    maxUncalculatedRatio,
    updatePool,
    expirationDate
  );
  allocationPoints = "20000";
  creatorToken = promiseToken.address;
  joinerToken = "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063";
  minUncalculatedRatio = ["1", "2000"];
  maxUncalculatedRatio = ["1", "1000"];
  updatePool = true;
  expirationDate = "1634554704";
  await promiseChef.add(
    allocationPoints,
    creatorToken,
    joinerToken,
    minUncalculatedRatio,
    maxUncalculatedRatio,
    updatePool,
    expirationDate
  );

  await deployer.deploy(Helper, promiseCore.address, promiseChef.address);
  const helper = await Helper.deployed();

  await deployer.deploy(WETHGateway, promiseCore.address, weth);
  const wethGateway = await WETHGateway.deployed();
};
