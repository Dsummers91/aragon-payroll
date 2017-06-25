var Payroll = artifacts.require("./Payroll.sol");
var USDToken = artifacts.require("./USDToken.sol");
var DuplicateUSDToken = artifacts.require("./DuplicateUSDToken.sol");

var USDTokenAddress;
var DuplicateUSDTokenAddress;
var USDToken;
var DuplicateUSDToken;
var payrollContract;

contract('USDToken', function (accounts) {
  it("Get USDToken Address", function () {
    return USDToken.deployed().then(function (instance) {
      USDToken = instance;
      USDTokenAddress = instance.address;
      assert.equal(USDTokenAddress, instance.address, "Owner is not first account");
    });
  });

  it("Get DuplicateUSDToken Address", function () {
    return DuplicateUSDToken.deployed().then(function (instance) {
      DuplicateUSDToken = instance;
      DuplicateUSDTokenAddress = instance.address;
      assert.equal(DuplicateUSDTokenAddress, instance.address, "Owner is not first account");
    });
  });
});
contract('Payroll', function (accounts) {


  it("payroll owner should be msg sender", function () {
    return Payroll.deployed().then(function (instance) {
      payrollContract = instance;
      payrollContract.owner.call((owner) => {
        return owner;
      }).then((owner) => {
        assert.equal(owner, accounts[0], "Owner is not first account");
      })
    });
  });

  it("Should create employee successfully and allocate funds", () => {
    return Payroll.deployed().then(() => {
      payrollContract.allowTokenGlobally(USDTokenAddress);
      return payrollContract;
    }).then(() => {
      payrollContract.allowTokenGlobally(DuplicateUSDTokenAddress);
      return payrollContract;
    }).then(() => {
      payrollContract.addEmployee(accounts[0], [USDTokenAddress, DuplicateUSDTokenAddress], 5000000);
      return payrollContract;
    }).then(() => {
      payrollContract.determineAllocation([USDTokenAddress, DuplicateUSDTokenAddress], [50,50])
      return payrollContract;
    }).then(() => {
      return payrollContract.setExchangeRate(USDTokenAddress, 100)
    }).then(() => {
      return payrollContract.setExchangeRate(DuplicateUSDTokenAddress, 50)
    }).then(() => {
      return payrollContract.getEmployee.call(0);
    }).then((tokens) => {
      assert.equal(tokens[3].toString(), [USDTokenAddress, DuplicateUSDTokenAddress].toString(), "tokens should be allowed");
      assert.equal(tokens[0].toString(), accounts[0], "account address should be msg sender");
    }).then(() => {
      return new Promise(res => setTimeout(res, 3001));
    }).then(() => {
      return payrollContract.payday();
    }).then(() => {
      return USDToken.balanceOf.call(accounts[0])
    }).then((balance) => {
      assert.equal(+balance.toString(), 2500000, "fsd");
    }).then(() => {
      return DuplicateUSDToken.balanceOf.call(accounts[0])
    }).then((balance) => {
      assert.equal(+balance.toString(), 5000000, "fsd");
    })
  })
});

