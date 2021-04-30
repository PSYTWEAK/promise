const path = require("path");
var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic =
  "syrup since document north quiz dignity position input heart essence age delay";
module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  contracts_build_directory: "/Users/nanoissuperior/prom/client/src/contracts",
  networks: {
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*",
    },
    kovan: {
      provider: function () {
        return new HDWalletProvider(
          mnemonic,
          "https://kovan.infura.io/v3/53a153fd3c6e4a149a223c45d3b91f75"
        );
      },
      network_id: 42,
      gas: 7500000,
      gasPrice: 1000000000,
    },
  },
  compilers: {
    solc: {
      version: "0.6.0",
      version: "0.6.12",
    },
  },
};
