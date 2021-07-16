const PromiseCore = artifacts.require("./PromiseCore.sol");
const PromiseFinder = artifacts.require("./PromiseFinder.sol");
const PromiseToken = artifacts.require("./token/PromiseToken.sol");
const TestToken = artifacts.require("./token/TestToken.sol");
const PromTest = artifacts.require("./test/PromTest.sol");
const ShareCalulator = artifacts.require("./lib/math/ShareCalculator.sol");

contract("Promise Core useage test", async (accounts) => {
  let prom, token1, token2, promTester;
  before("Set up", async () => {
    promCore = await PromiseCore.new(accounts[0]);
    promFinder = await PromiseFinder.new(promCore.address);
    token1 = await PromiseToken.new();
    token2 = await TestToken.new();
    promTester = await PromTest.new(
      promCore.address,
      promFinder.address,
      token1.address,
      token2.address
    );
    await token1.mint(promTester.address, "8438438473848345454343454354", {
      from: accounts[0],
    });
    await token2.mint(promTester.address, "3487584937589454544758487954", {
      from: accounts[0],
    });
  });

  it("Scenario One - Creator makes promise, alice and bob join half each, all 3 pay", async () => {
    await promTester.scenario1();
  });
  it("All participants execute with correct amounts paid out", async () => {
    await promTester.scenario1Execution();
  });
  it("Scenario Two - Creator makes promise, alice and bob join fractions each, all 3 pay", async () => {
    await promTester.scenario2();
  });
  it("All participants execute with correct amounts paid out", async () => {
    await promTester.scenario2Execution();
  });
  it("Scenario Three - Creator makes promise, alice and bob join fractions each, 2 pay alice doesn't", async () => {
    await promTester.scenario3();
  });
  it("All participants except alice execute with correct amounts paid out", async () => {
    await promTester.scenario3Execution();
  });
  it("Scenario Four - Creator makes promise, alice and bob join fractions each, 2 pay creator doesn't and 3 execute", async () => {
    await promTester.scenario4();
  });
  it("Creator closes pending amount and is paid out correctly", async () => {
    await promTester.scenario5ClosePendingAmount();
  });
  it("All participants execute with correct amounts paid out", async () => {
    await promTester.scenario4Execution();
  });

  it("Scenario Five - Creator makes promise, lots of users join, some pay and some execute", async () => {
    await promTester.scenario5();
    for (var i = 1; i < 8; i++) {
      await promTester.scenario5JoiningAndPaying(accounts[i]);
    }
  });
  it("Creator closes pending amount and is paid out correctly", async () => {
    await promTester.scenario5ClosePendingAmount();
  });
  it("All participants execute with correct amounts paid out", async () => {
    // await promTester.scenario5ForCreator();
    for (var i = 1; i < 8; i++) {
      await promTester.scenario5Execution(accounts[i]);
    }
  });

  it(`Promise spam number, creating, joining and executing`, async () => {
    await promTester.scenario5();
    for (var i = 1; i < 8; i++) {
      await promTester.scenario5JoiningAndPaying(accounts[i]);
    }
    await promTester.scenario5ClosePendingAmount();
    await promTester.scenario5ForCreator();
    for (var i = 1; i < 8; i++) {
      await promTester.scenario5Execution(accounts[i]);
      await promTester.hasLeftOver();
    }
  });
});
