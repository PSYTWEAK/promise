var PromController = artifacts.require("./PromController.sol");
const PromToken = artifacts.require("./token/PromToken.sol");
const TestToken = artifacts.require("./token/TestToken.sol");
const Helper = artifacts.require("./Helper.sol");
const WETHGateway = artifacts.require("./WETHGateway.sol");

var uni = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
var dai = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
var weth = "0xd0a1e359811322d97991e03f863a0c30c2cf029c";
var me = "0x1E67cC1199F312d495694D99C57a3667fBb6FCe5";

module.exports = async function (deployer, accounts) {
  await deployer.deploy(
    PromController,
    "0x1E67cC1199F312d495694D99C57a3667fBb6FCe5"
  );

  await deployer.deploy(PromToken);
  await deployer.deploy(TestToken);

  var prom = await PromController.deployed();
  var promToken = await PromToken.deployed();
  var testToken = await TestToken.deployed();

  await deployer.deploy(Helper, prom.address);
  var helper = await Helper.deployed();

  await deployer.deploy(WETHGateway, prom.address, weth);
  var wethGateway = await WETHGateway.deployed();
};
