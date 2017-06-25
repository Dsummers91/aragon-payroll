var Payroll = artifacts.require("./Payroll.sol");
var USDToken = artifacts.require("./USDToken.sol");
var DuplicateUSDToken = artifacts.require("./DuplicateUSDToken.sol");


module.exports = function(deployer) {
  deployer.deploy(USDToken)
    .then(() => {
      return deployer.deploy(DuplicateUSDToken)
        .then(() => {
          return deployer.deploy(Payroll, [USDToken.address, DuplicateUSDToken.address]);
        })
    });
};
