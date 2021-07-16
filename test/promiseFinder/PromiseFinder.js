var Web3 = require("web3");
var web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:9545"));

const PromiseCore = artifacts.require("./PromiseCore.sol");
const PromiseFinder = artifacts.require("./PromiseFinder.sol");
const PromiseToken = artifacts.require("./token/PromiseToken.sol");
const TestToken = artifacts.require("./token/TestToken.sol");
const PromTest = artifacts.require("./test/PromTest.sol");
const ShareCalulator = artifacts.require("./lib/math/ShareCalculator.sol");

contract("Quick test for PromiseFinder", async (accounts) => {
  before("Deploy Contracts and mint test tokens", async () => {
    promCore = await PromiseCore.new(accounts[0]);
    promFinder = await PromiseFinder.new(promCore.address);
    promiseToken = await PromiseToken.new();
    testToken = await TestToken.new();
    promTester = await PromTest.new(
      promCore.address,
      promFinder.address,
      promiseToken.address,
      testToken.address
    );
    await promiseToken.mint(
      promTester.address,
      "8438438473848345454343454354",
      {
        from: accounts[0],
      }
    );
    await testToken.mint(
      promTester.address,
      "3487584937589454544758487797897879897954",
      {
        from: accounts[0],
      }
    );
  });
  before("Create some random Promises", async () => {
    await promTester.createPromise();
    await promTester.createPromise_2();
  });

  it("Account promises", async () => {
    let result = await promFinder.accountPromises(promTester.address);
    console.log(result);
  });
  it("Joinable promises", async () => {
    let min = Math.round(Date.now() / 1000);
    let max = "1630073374";
    console.log(min);
    console.log(max);

    let result = await promFinder.getPopulatedJoinableTimeIntervals(
      promiseToken.address,
      testToken.address,
      min,
      max
    );
    let timeIntervals = result.expirationTimestampWithinInterval.map(String);
    let numberOfPromises = result.numOfPromisesInTimeInterval.map(String);
    let i = 0;

    while (i < timeIntervals.length) {
      if (numberOfPromises[i] === "0") {
        timeIntervals.splice(i, 1);
        numberOfPromises.splice(i, 1);
      } else {
        i++;
      }
    }
    console.log(timeIntervals);
    result = await promFinder.getPopulatedJoinableListIds(
      promiseToken.address,
      testToken.address,
      timeIntervals,
      "30"
    );
    console.log(result.lengths.toString());
    console.log(result.listIds);
    result = await promFinder._joinablePromisesRaw(result.listIds, "200");
    console.log(result.expirationTimestamp[0].toString());
  });
});
