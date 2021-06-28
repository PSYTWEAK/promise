var Web3 = require("web3");
var web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:9545"));

const timeTravel = require("./TimeTravel.js");
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
      "1000000000000000000",
      "100"
    );
    promiseHolder = await PromiseHolder.new(
      promiseCore.address,
      promiseChef.address
    );
  });
  before("Config", async () => {
    await promiseToken.mint(accounts[0], "8438438473848345454343454354", {
      from: accounts[0],
    });
    await promiseToken.approve(
      promiseChef.address,
      "8438438473848345454343454354"
    );

    await testToken.mint(accounts[0], "3487584937589454544758487954", {
      from: accounts[0],
    });
    await testToken.approve(
      promiseChef.address,
      "8438438473848345454343454354"
    );
    await promiseToken.transferOwnership(promiseChef.address);
    await promiseChef.setPromiseHolder(promiseHolder.address);
  });
  it("Adding Promise Token / Test Token pool", async () => {
    const allocationPoints = "10000";
    const creatorToken = promiseToken.address;
    const joinerToken = testToken.address;
    const minUncalculatedRatio = ["10000", "9000"];
    const maxUncalculatedRatio = ["10000", "1000"];
    const updatePool = true;
    const expirationDate = "74384738437843983";
    await promiseChef.add(
      allocationPoints,
      creatorToken,
      joinerToken,
      minUncalculatedRatio,
      maxUncalculatedRatio,
      updatePool,
      expirationDate
    );
    const poolInfo = await promiseChef.poolInfo(0);
  });
  it("joining pool 0 as account[0]", async () => {
    const poolId = "0";
    const creatorAmount = "10000";
    const joinerAmount = "8000";
    await promiseChef.createPromise(poolId, creatorAmount, joinerAmount);
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
