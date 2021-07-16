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

contract("Quick test for PromiseChef", async (accounts) => {
  let promiseCore, token1, token2, promiseChef;
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
    await promiseToken.mint(accounts[0], TEST_DATA.USER.promiseTokenToMint, {
      from: accounts[0],
    });
    await promiseToken.approve(
      promiseChef.address,
      TEST_DATA.USER.promiseTokenToApprove
    );

    await testToken.mint(accounts[0], TEST_DATA.USER.promiseTokenToMint, {
      from: accounts[0],
    });
    await testToken.approve(
      promiseChef.address,
      TEST_DATA.USER.promiseTokenToApprove
    );
    await promiseToken.transferOwnership(promiseChef.address);
    await promiseChef.setPromiseHolder(promiseHolder.address);
  });
  it("Adding Promise Token / Test Token pool", async () => {
    await promiseChef.add(
      TEST_DATA.POOL_0.allocationPoints,
      promiseToken.address,
      testToken.address,
      TEST_DATA.POOL_0.minUncalculatedRatio,
      TEST_DATA.POOL_0.maxUncalculatedRatio,
      TEST_DATA.POOL_0.updatePool,
      TEST_DATA.POOL_0.expirationDate
    );
    const poolInfo = await promiseChef.poolInfo(0);
  });
  it("joining pool 0 as account[0]", async () => {
    await promiseChef.createPromise(
      0,
      TEST_DATA.CREATE_PROMISE.creatorAmount,
      TEST_DATA.CREATE_PROMISE.joinerAmount
    );
  });
  it("claiming rewards", async () => {
    const poolId = 0;
    const promiseId = 1;
    await timeTravel.advanceBlock();
    await promiseChef.claimReward(poolId, promiseId);
  });
  it("closing pending amount", async () => {
    const poolId = 0;
    const promiseId = 1;
    await promiseChef.closePendingPromiseAmount(poolId, promiseId);
  });
  it("create, pay Promise and execute", async () => {
    const poolId = "0";
    const creatorAmount = "10000";
    const joinerAmount = "8000";
    const promiseId = 2;
    await promiseChef.createPromise(poolId, creatorAmount, joinerAmount);
    await promiseChef.payPromise(promiseId);
    await promiseChef.executePromise(poolId, promiseId, accounts[0]);
  });
});
