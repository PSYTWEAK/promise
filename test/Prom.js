const PromiseCore = artifacts.require("./PromiseCore.sol");
const Token1 = artifacts.require("./token/Token1.sol");
const Token2 = artifacts.require("./token/Token2.sol");
const Helper = artifacts.require("./Helper.sol");

contract("PromCore", (accounts) => {
  let prom, token1, token2, promTester;

  before("creating promises", async () => {
    prom = await PromiseCore.new(accounts[0]);
    token1 = await Token1.new();
    token2 = await Token2.new();
    promTester = await promTester.new();
    promTester.setTokens(token1.address, token2.address);
    promTester.setPromiseCore(prom.address);
  });
  it("Test 1 create promises", () => {
    promTester.createPromise().catch((err) => console.log(err));
  });
  it("Test 2 join all 3 promises with 2 joiners ", () => {
    promTester.joinerJoinAllPromises().catch((err) => console.log(err));
  });
});
