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
  const promiseToken = await PromiseToken.deployed();
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
  let joinerToken = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
  let minUncalculatedRatio = ["1", "100"];
  let maxUncalculatedRatio = ["1", "70"];
  let updatePool = true;
  let expirationDate = "1638796682";
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
  joinerToken = "0x144edb9c8504e1b8b0323ecf6a7bf02c0e671167";
  minUncalculatedRatio = ["1", "2000"];
  maxUncalculatedRatio = ["1", "1000"];
  updatePool = true;
  expirationDate = "1638796682";
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
