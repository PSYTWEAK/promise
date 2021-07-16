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
    await promiseToken.mint(accounts[0], TEST_DATA.USER.promiseTokenToMint, {
      from: accounts[0],
    });
    await promiseToken.approve(
      promiseChef.address,
      TEST_DATA.USER.promiseTokenToApprove
    );
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
    await promiseChef.createPromise(
      0,
      TEST_DATA.CREATE_PROMISE.creatorAmount,
      TEST_DATA.CREATE_PROMISE.joinerAmount
    );
  });
  it("Pay Promise", async () => {
    const balanceBefore = await promiseToken.balanceOf(accounts[0]);
    await promiseChef.payPromise(1);
    const expectedAmountTaken = TEST_DATA.CREATE_PROMISE.creatorAmount / 2;
    const expectedBalanceAfter = balanceBefore - expectedAmountTaken;
    const balanceAfter = await promiseToken.balanceOf(accounts[0]);
    assert.equal(expectedBalanceAfter, balanceAfter);
  });
  it("Check Data inside of the promise", async () => {
    const promise = await promiseCore.promises(1);
    assert.equal(
      promise.creatorAmount,
      TEST_DATA.CREATE_PROMISE.expectedCreatorAmount
    );
    assert.equal(promise.creatorDebt, 0);
    assert.equal(
      promise.joinerAmount,
      TEST_DATA.CREATE_PROMISE.expectedJoinerAmount
    );
    assert.equal(
      promise.joinerPaidFull,
      TEST_DATA.CREATE_PROMISE.expectedJoinerPaidFull
    );
    assert.equal(
      promise.joinerDebt,
      TEST_DATA.CREATE_PROMISE.expectedJoinerDebt
    );
  });
});
