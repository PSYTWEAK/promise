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

let promiseCounter = 1;
let promiseFeeBP;
let promiseFeeTaken;

contract("PromiseChef", async (accounts) => {
  before("Deploy contracts", async () => {
    promiseCore = await PromiseCore.new(accounts[1]);
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
    await promiseToken.mint(accounts[1], TEST_DATA.USER.promiseTokenToMint, {
      from: accounts[0],
    });
    await promiseToken.mint(
      promiseHolder.address,
      TEST_DATA.USER.promiseTokenToMint
    );
    await promiseToken.approve(
      promiseChef.address,
      TEST_DATA.USER.promiseTokenToApprove
    );
    await testToken.approve(
      promiseCore.address,
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
      Math.round(Date.now() / 1000) + 1000
    );
    promiseFeeBP = await promiseCore.feeBP();
    promiseFeeTaken =
      (parseInt(TEST_DATA.CREATE_PROMISE.creatorAmount) *
        parseInt(promiseFeeBP)) /
      10000;
    assert.equal(50, promiseFeeBP);
  });
  beforeEach("Config", async () => {
    await promiseChef.createPromise(
      0,
      TEST_DATA.CREATE_PROMISE.creatorAmount,
      TEST_DATA.CREATE_PROMISE.joinerAmount
    );
    await promiseChef.payPromise(promiseCounter);
    promiseCounter++;
  });
  it("Close pending Promise amount from PromiseChef", async () => {
    const balanceBefore = await promiseToken.balanceOf(accounts[0]);
    const expectedBalanceAfter =
      parseInt(balanceBefore) +
      (parseInt(TEST_DATA.CREATE_PROMISE.creatorAmount) -
        parseInt(promiseFeeTaken));
    await promiseChef.closePendingPromiseAmount(0, 1);
    const balanceAfter = await promiseToken.balanceOf(accounts[0]);
    assert.equal(50, promiseFeeBP);
    assert.equal(
      balanceAfter.toString(),
      expectedBalanceAfter.toLocaleString("full-width", { useGrouping: false })
    );
  });
  it("Close pending Promise amount after joiner has entered", async () => {
    await promiseCore.joinPromise(
      2,
      accounts[1],
      Math.round(
        TEST_DATA.CREATE_PROMISE.joinerAmount / 2
      ).toLocaleString("full-width", { useGrouping: false })
    );
    const balanceBefore = await promiseToken.balanceOf(accounts[0]);
    const expectedFee =
      ((parseInt(TEST_DATA.CREATE_PROMISE.creatorAmount) / 2) * promiseFeeBP) /
      10000;
    const expectedRefund =
      parseInt(TEST_DATA.CREATE_PROMISE.creatorAmount) / 2 - expectedFee;
    const expectedBalanceAfter = parseInt(balanceBefore) + expectedRefund;
    await promiseChef.closePendingPromiseAmount(0, 2);
    const balanceAfter = await promiseToken.balanceOf(accounts[0]);
    assert.equal(
      balanceAfter.toString(),
      expectedBalanceAfter.toLocaleString("full-width", {
        useGrouping: false,
      })
    );
  });
  it("Check double execution fails", async () => {
    let hasSucceeded0 = true;
    let hasSucceeded1 = true;
    try {
      await promiseChef.closePendingPromiseAmount(0, 1);
    } catch {
      hasSucceeded0 = false;
    }
    try {
      await promiseChef.closePendingPromiseAmount(0, 2);
    } catch {
      hasSucceeded1 = false;
    }
    assert.equal(false, hasSucceeded0);
    assert.equal(false, hasSucceeded1);
  });
});
