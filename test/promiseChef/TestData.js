var TEST_DATA = {
  DEPLOY: {
    promPerBlock: (1 * Math.pow(10, 18)).toLocaleString("fullwide", {
      useGrouping: false,
    }),
    startBlock: "100",
    endBlock: "1000000000000000000",
  },

  USER: {
    promiseTokenToMint: (1000 * Math.pow(10, 7)).toLocaleString("fullwide", {
      useGrouping: false,
    }),
    promiseTokenToApprove: (1000 * Math.pow(10, 7)).toLocaleString("fullwide", {
      useGrouping: false,
    }),
  },

  POOL_0: {
    allocationPoints: "10000",
    minUncalculatedRatio: ["10000", "9000"],
    maxUncalculatedRatio: ["10000", "1000"],
    updatePool: true,
    expirationDate: "1638796682",
  },

  POOL_1: {
    allocationPoints: "2000",
    minUncalculatedRatio: ["10000", "9000"],
    maxUncalculatedRatio: ["10000", "1000"],
    updatePool: true,
    expirationDate: "1638796682",
  },

  CREATE_PROMISE: {
    creatorAmount: "100000",
    joinerAmount: "80000",
    expectedCreatorAmount: "100000",
    expectedCreatorDebt: "50000",
    expectedJoinerAmount: "80000",
    expectedJoinerPaidFull: 0,
    expectedJoinerDebt: 0,
  },
};

module.exports = TEST_DATA;
