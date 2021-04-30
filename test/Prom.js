var PromController = artifacts.require("./PromController.sol");
const Token1 = artifacts.require("./token/Token1.sol");
const Token2 = artifacts.require("./token/Token2.sol");
const Helper = artifacts.require("./Helper.sol");

var uni = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
var dai = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
var weth = "0xd0a1e359811322d97991e03f863a0c30c2cf029c";
var account2 = "0x8960989aCe6737F2a3317951E6De8E7E2d518d0e";

const BigNumber = require("bignumber.js");

function amounts(n) {
  return new BigNumber(`${n}e18`);
}

function consoleIds(info) {
  if (info[0].length > 0) {
    for (var i = 0; i < info[0].length; i++) {
      console.log("id " + info[0][i].toString());
    }
  }
}
function consoleOwed(info, num) {
  if (info[0].length > 0) {
    for (var i = 0; i < info[0].length; i++) {
      console.log("id " + info[0][i].toString());
      console.log((info[num][i] / 1e18).toString() + " Owes");
    }
  }
}
const increaseTime = (addSeconds) => {
  web3.currentProvider.send({
    jsonrpc: "2.0",
    method: "evm_decreaseTime",
    params: [addSeconds],
    id: 0,
  });
};
function timeout(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

contract("PromController", (accounts) => {
  let prom, token1, token2, helper, index, acc0Balance, acc1Balance;
  let numOfPromises = 10;
  let numWeeks = 2;
  let now = new Date();
  let promiseEnd = Math.round(Date.now() / 1000) + 30;

  before("creating promises", async () => {
    prom = await PromController.new(accounts[0]);
    token1 = await Token1.new();
    token2 = await Token2.new();
    helper = await Helper.new(weth, prom.address);
    await token1.approve(prom.address, amounts(10000000), {
      from: accounts[0],
    });
    await token2.approve(prom.address, amounts(10000000), {
      from: accounts[0],
    });
    acc0Balance = await token1.balanceOf(accounts[0]);
    acc1Balance = await token1.balanceOf(accounts[1]);
    for (var i = 0; i < numOfPromises; i++) {
      await prom.createPromise(
        accounts[0],
        amounts(100),
        token1.address,
        amounts(100),
        token2.address,
        promiseEnd
      );
    }
  });

  it("Test 1 create and return Joinable promises", async () => {
    await prom
      .getPromises_Asset_Amount(
        accounts[0],
        false,
        token1.address,
        token2.address
      )
      .then((result) => {
        assert.equal(
          result[0].length,
          numOfPromises,
          "Correct number of promises added"
        );
      });
  });
  it("Test 2 cancel all of joinable promises", async () => {
    await prom
      .getPromises_Asset_Amount(accounts[0], true, accounts[0], accounts[0])
      .then((result) => {
        console.log("------account[0] Promises Before cancel-----");
        consoleIds(result);
        assert.equal(
          result[0].length,
          numOfPromises,
          "Correct number of promises joined"
        );
      });
    await prom
      .getPromises_Asset_Amount(
        accounts[0],
        false,
        token1.address,
        token2.address
      )
      .then((result) => {
        console.log("------Joinable Promises Before cancel-----");
        consoleIds(result);
      });
    let accIndex, joIndex;
    let arrayOfIds = [];
    await prom
      .getPromises_Asset_Amount(accounts[0], true, accounts[0], accounts[0])
      .then((result) => {
        for (var i = 0; i < result[0].length; i++) {
          arrayOfIds.push(result[0][i]);
        }
        assert.equal(
          result[0].length,
          numOfPromises,
          "Correct number of promises"
        );
      });

    let arrayOfAccountIndex = [];
    let arrayOfJoinableIndex = [];
    for (var i = 0; i < arrayOfIds.length; i++) {
      accIndex = await prom.getIndexAccount(
        arrayOfIds[i].toString(),
        accounts[0]
      );
      joIndex = await prom.getIndexJoinable(arrayOfIds[i].toString());
      arrayOfAccountIndex.push(accIndex);
      arrayOfJoinableIndex.push(joIndex);
    }

    for (var i = 0; i < arrayOfIds.length; i++) {
      await prom.cancelPromise(
        arrayOfIds[i],
        arrayOfAccountIndex[i],
        arrayOfJoinableIndex[i]
      );
    }
  });
  it("Test 3 create and join all joinable promises", async () => {
    for (var i = 0; i < numOfPromises; i++) {
      await prom.createPromise(
        accounts[0],
        amounts(100),
        token1.address,
        amounts(100),
        token2.address,
        promiseEnd
      );
    }
    let joinablePromises = await prom.getPromises_Asset_Amount(
      accounts[0],
      false,
      token1.address,
      token2.address
    );
    let arrayOfIndex = [];
    for (var i = 0; i < joinablePromises[0].length; i++) {
      index = await prom.getIndexJoinable(joinablePromises[0][i].toString());
      arrayOfIndex.push(index);
    }

    for (var i = 0; i < joinablePromises[0].length; i++) {
      await prom
        .joinPromise(
          joinablePromises[0][i].toString(),
          accounts[1],
          arrayOfIndex[i]
        )
        .then((result) => {
          assert(result.receipt.gasUsed < 190000, "gas broke 190,000");
          new Promise((r) => setTimeout(r, 2000));
        });
    }
    joinablePromises = await prom.getPromises_Asset_Amount(
      accounts[1],
      false,
      token1.address,
      token2.address
    );
    await prom
      .getPromises_Asset_Amount(accounts[0], true, accounts[0], accounts[0])
      .then((result) => {
        console.log("------ Account[0] Promises at the end of joining ------");
        consoleIds(result);
        assert.equal(
          result[0].length,
          numOfPromises,
          "Correct number of promises joined"
        );
      });
    await prom
      .getPromises_Asset_Amount(accounts[1], true, accounts[0], accounts[0])
      .then((result) => {
        console.log("------ Account[1] Promises at the end of joining ------");
        consoleIds(result);
        assert.equal(
          result[0].length,
          numOfPromises,
          "Correct number of promises joined"
        );
      });
  });
  it("Test 4 pay all promises as account[0] and half as account[1]", async () => {
    let account0PromiseIds = [];
    let account1PromiseIds = [];
    await prom
      .getPromises_owed(accounts[0], true, accounts[0], accounts[0])
      .then((result) => {
        console.log("------ Creator acc[0] owed before payment ------");
        consoleOwed(result, 1);
        for (var i = 0; i < result[0].length; i++) {
          account0PromiseIds.push(result[0][i]);
        }
      });
    await prom
      .getPromises_owed(accounts[1], true, accounts[0], accounts[0])
      .then((result) => {
        console.log("------ Joiner acc[1] owed before payment ------");
        consoleOwed(result, 2);
        for (var i = 0; i < result[0].length; i++) {
          account1PromiseIds.push(result[0][i]);
        }
      });
    for (var i = 0; i < account0PromiseIds.length; i++) {
      await prom.payPromise(account0PromiseIds[i], accounts[0]);
    }
    for (var i = 0; i < account1PromiseIds.length / 2; i++) {
      await prom.payPromise(account1PromiseIds[i], accounts[1]);
    }
    await prom
      .getPromises_owed(accounts[0], true, accounts[0], accounts[0])
      .then((result) => {
        console.log("------ Creator acc[0] owed after payment ------");
        consoleOwed(result, 1);
        for (var i = 0; i < result[0].length; i++) {
          account0PromiseIds.push(result[0][i]);
        }
      });
    await prom
      .getPromises_owed(accounts[1], true, accounts[0], accounts[0])
      .then((result) => {
        console.log(
          "------ Joiner acc[1] owed after payment (half should be unpaid) ------"
        );
        consoleOwed(result, 2);
        for (var i = 0; i < result[0].length; i++) {
          account1PromiseIds.push(result[0][i]);
        }
      });
  });
  it("Test 5 execute all promises", async () => {
    await timeout(60 * 1000);
    let arrayOfIds = [];
    await prom
      .getPromises_Asset_Amount(accounts[0], true, accounts[0], accounts[0])
      .then((result) => {
        for (var i = 0; i < result[0].length; i++) {
          arrayOfIds.push(result[0][i]);
        }
      });

    let arrayOfAccount0Index = [];
    let arrayOfAccount1Index = [];
    for (var i = 0; i < arrayOfIds.length; i++) {
      acc0Index = await prom.getIndexAccount(
        arrayOfIds[i].toString(),
        accounts[0]
      );
      arrayOfAccount0Index.push(acc0Index);
      acc1Index = await prom.getIndexAccount(
        arrayOfIds[i].toString(),
        accounts[1]
      );
      arrayOfAccount1Index.push(acc1Index);
    }

    for (var i = 0; i < arrayOfAccount0Index.length; i++) {
      await prom
        .executePromise(
          arrayOfIds[i],
          arrayOfAccount0Index[i],
          arrayOfAccount1Index[i]
        )
        .then((result) => {
          console.log(result.receipt.gasUsed);
        });
    }
    console.log("------ Balance of account[0] before------");
    console.log(acc0Balance.toString());
    console.log("------ Balance of account[1] before------");
    console.log(acc1Balance.toString());
    acc0Balance = await token1.balanceOf(accounts[0]);
    acc1Balance = await token1.balanceOf(accounts[1]);
    console.log("------ Balance of account[0] after ------");
    console.log(acc0Balance.toString());
    console.log("------ Balance of account[1] after ------");
    console.log(acc1Balance.toString());
  });
});
