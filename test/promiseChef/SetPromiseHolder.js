var Web3 = require("web3");
var web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:9545"));

const timeTravel = require("../TimeTravel.js");
const TEST_DATA = require("./TestData.js");
const PromiseCore = artifacts.require("./PromiseCore.sol");
const PromiseToken = artifacts.require("./token/PromiseToken.sol");
const PromiseChef = artifacts.require("./farms/PromiseChef.sol");
const PromiseHolder = artifacts.require("./farms/PromiseHolder.sol");
const TestToken = artifacts.require("./token/TestToken.sol");
const ShareCalulator = artifacts.require("./lib/math/ShareCalculator.sol");

contract("PromiseChef", async (accounts) => {
  before("Deploy contracts", async () => {
    promiseCore = await PromiseCore.new(accounts[0]);
    promiseToken = await PromiseToken.new();
    testToken = await TestToken.new();
    promiseChef = await PromiseChef.new(
      promiseToken.address,
      promiseCore.address,
      TEST_DATA.DEPLOY.promPerBlock,
      TEST_DATA.DEPLOY.startBlock,
      TEST_DATA.DEPLOY.endBlock
    );
    promiseHolder = await PromiseHolder.new(
      promiseCore.address,
      promiseChef.address
    );
  });
  before("Config", async () => {
    await promiseToken.transferOwnership(promiseChef.address);
    await promiseChef.setPromiseHolder(promiseHolder.address);
    await promiseChef.add(
      TEST_DATA.POOL_0.allocationPoints,
      promiseToken.address,
      testToken.address,
      TEST_DATA.POOL_0.minUncalculatedRatio,
      TEST_DATA.POOL_0.maxUncalculatedRatio,
      TEST_DATA.POOL_0.updatePool,
      TEST_DATA.POOL_0.expirationDate
    );
  });
  it("Setting Promise Holder", async () => {
    await promiseChef.setPromiseHolder(accounts[2]);
    const promiseHolder = await promiseChef.promiseHolder();
    assert.equal(accounts[2], promiseHolder);
  });
});
