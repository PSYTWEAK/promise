const PromiseCore = artifacts.require("./PromiseCore.sol");
const PromToken = artifacts.require("./token/PromToken.sol");
const TestToken = artifacts.require("./token/TestToken.sol");
const Helper = artifacts.require("./Helper.sol");
const WETHGateway = artifacts.require("./WETHGateway.sol");
const PromTest = artifacts.require("./test/PromTest.sol");
const ShareCalulator = artifacts.require("./lib/math/ShareCalculator.sol");
var weth = "0xd0a1e359811322d97991e03f863a0c30c2cf029c";

module.exports = async function (deployer, accounts) {
  await deployer.deploy(ShareCalulator);
  await deployer.link(ShareCalulator, PromiseCore);
  await deployer.deploy(
    PromiseCore,
    "0x1E67cC1199F312d495694D99C57a3667fBb6FCe5"
  );

  await deployer.deploy(PromToken);
  await deployer.deploy(TestToken);

  var prom = await PromiseCore.deployed();
  var promToken = await PromToken.deployed();
  var testToken = await TestToken.deployed();

  await deployer.deploy(Helper, prom.address);
  var helper = await Helper.deployed();

  await deployer.deploy(WETHGateway, prom.address, weth);
  var wethGateway = await WETHGateway.deployed();
};
