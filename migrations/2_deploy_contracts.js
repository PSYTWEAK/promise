var PromController = artifacts.require("./PromController.sol");
const PromToken = artifacts.require("./token/PromToken.sol");
const Token2 = artifacts.require("./token/Token2.sol");
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

  await deployer.deploy(Token1);
  await deployer.deploy(Token2);

  var prom = await PromController.deployed();
  var promToken = await PromToken.deployed();
  var token2 = await Token2.deployed();

  await deployer.deploy(Helper, prom.address);
  var helper = await Helper.deployed();

  await deployer.deploy(WETHGateway, prom.address, weth);
  var wethGateway = await WETHGateway.deployed();

  await promToken.approve(prom.address, "100000000000000000000000");

  for (var i; i < 5; i++) {
    await prom.createPromise(
      accounts[0],
      "0x1E67cC1199F312d495694D99C57a3667fBb6FCe5",
      "10000000000000000000",
      promToken.address,
      "10000000000000000000",
      token2.address,
      "1628246300"
    );
  }

  for (var i; i < 5; i++) {
    await wethGateway.createPromiseWithETH(
      accounts[0],
      "10000000000000000000",
      token2.address,
      "1628246300"
    );
  }
};
