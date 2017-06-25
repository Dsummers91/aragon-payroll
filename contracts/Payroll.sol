pragma solidity ^0.4.11;

import './PayrollInterface.sol';
import './github.com/ConsenSys/Tokens/Token_Contracts/contracts/Token.sol';

contract Payroll is PayrollInterface {
  Employee[] public employees;
  address[] public globallyAllowedTokens;
  address public owner;
  uint256 public paydayFrequencyInDays = 2;
  uint256 public lastPayday;
  mapping (address => uint256) exchangeRates;

  struct Employee {
    uint256 employeeID;
    address accountAddress;
    uint256 yearlyUSDSalary;
    address[] allowedTokens;
    address[] tokens;
    uint256[] distribution;
    uint256 startDate;
  }

  function Payroll(address[] tokens) {
    lastPayday = now;
    owner = msg.sender;
    globallyAllowedTokens = tokens;
    initTestData();
  }

  function initTestData() internal {
    setExchangeRate(globallyAllowedTokens[0], 100);
    setExchangeRate(globallyAllowedTokens[1], 50);
  }

  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) {
    for(uint i = 0; i < allowedTokens.length; i++) {
      require(existsInArray(globallyAllowedTokens, allowedTokens[i]));
    }
    uint256 employeeID;
    if(employees.length == 0) {
      employeeID = 0;
    } else {
      employeeID = employees[employees.length-1].employeeID + 1; // Increment latest employee's employeeID
    }
    Employee memory employee;
    employee.employeeID = employeeID;
    employee.accountAddress = accountAddress;
    employee.yearlyUSDSalary =  initialYearlyUSDSalary;
    employee.allowedTokens = allowedTokens;
    employee.startDate = now;
    employees.push(employee);
  }

  function setEmployeeSalary(uint256 employeeID, uint256 yearlyUSDSalary) isOwner {
    employeeID = getEmployeeIndex(employeeID);
    employees[employeeID].yearlyUSDSalary = yearlyUSDSalary;
  }


  // TODO: Should pay employees due salary in this method also.
  function removeEmployee(uint256 employeeID) isOwner {
    uint index = getEmployeeIndex(employeeID);
    removeEmployeeIndex(index);
  }

  function scapeHatch() isOwner {
    selfdestruct(owner);
  }


  function allowTokenGlobally(address _token)  {
    globallyAllowedTokens.push(_token);
  }

  // For tokens that aren't allowed globally, but have been sent to this address
  // Owner has ability to send those tokens anywhere (hopefully back to rightful owner)
  function refundToken(address _token, address _to, uint256 _amount) tokenIsNotAllowed(_token) isOwner returns(bool) {
      Token ERC20 = Token(address(_token));
      return ERC20.transfer(_to, _amount);
  }

  function getEmployeeCount() constant returns (uint256) {
    return employees.length - 1;
  }

  function getEmployee(uint256 employeeID) constant returns (
    address employeeAddress, 
    uint256 salary, 
    uint256 startDate,
    address[] tokens,
    uint256[] distribution) {
    uint index = getEmployeeIndex(employeeID);
    Employee employee = employees[index];
    employeeAddress = employee.accountAddress;
    salary = employee.yearlyUSDSalary;
    startDate = employee.startDate;
    tokens = employee.tokens;
    distribution = employee.distribution;
    return (employeeAddress,salary,startDate, tokens, distribution);
  }

  function calculatePayrollBurnrate() constant returns (uint256) {
     uint256 burnRate = 0;
     for (uint i = 0; i<employees.length; i++) {
        burnRate += employees[i].yearlyUSDSalary;
    }
    return burnRate;
  }
  
  function calculatePayrollRunway() constant returns (uint256) {
    uint256 burnRate = calculatePayrollBurnrate();
    return (this.balance / burnRate);
  }

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution) {
    require(tokens.length == distribution.length);
    uint256 totalDistribution;
    uint256 index = getEmployeeIndexByAddress(msg.sender);
    Employee employee = employees[index];
    uint numberOfIterations;
    if(employee.tokens.length > tokens.length) {
      numberOfIterations = employee.tokens.length;
    } else {
      numberOfIterations = tokens.length;
    }
    for(uint i = 0; i < numberOfIterations; i++) {
      if(i < tokens.length && i >= employee.tokens.length) {
        require(existsInArray(employee.allowedTokens, tokens[i]));
        employee.tokens.push(tokens[i]);
        employee.distribution.push(distribution[i]);
        totalDistribution += distribution[i];
      } else if (i < tokens.length && i < employee.tokens.length) {
        require(existsInArray(employee.allowedTokens, tokens[i]));
        employee.tokens[i] = tokens[i];
        employee.distribution[i] = distribution[i];
        totalDistribution += distribution[i];
      } else {
        delete employee.tokens[i];
        employee.tokens.length--;
        delete employee.distribution[i];
        employee.distribution.length--;
      }
    }
    require(totalDistribution == 100);
  }

  function payday() {
    uint256 paidDate = lastPayday + (paydayFrequencyInDays * 1 seconds); //Change to days in prod..
    require(now > paidDate);
    lastPayday = paidDate;
    for (uint i = 0; i < employees.length; i++){
        payEmployee(employees[i]);
    }
  }

  /* ORACLE ONLY */
  // Set the Exchange Rate in relation to 100 USD Tokens
  // 100 ERC Tokens = $1.00
  function setExchangeRate(address token, uint256 usdExchangeRate) isOracle {
    exchangeRates[token] = usdExchangeRate;
  }

  modifier isOwner {
    if(owner == msg.sender) _;
  }

  modifier isOracle {
    _;
  }

  modifier tokenIsNotAllowed(address _token) {
    for(uint i = 0; i < globallyAllowedTokens.length; i++) {
      if(globallyAllowedTokens[i] == _token) throw;
    }
    _;
  }

  function existsInArray(address[] list, address item) internal returns(bool){
    for(uint i = 0; i < list.length; i++) {
      if(list[i] == item) return true;
    }
    return false;
  }

  /* Internal */
  function getEmployeeIndex(uint256 employeeID) internal returns(uint) {
    for (uint i = 0; i<employees.length; i++) {
        if(employees[i].employeeID == employeeID) return i;
    }
    throw;
  }

  // I have some discomfort with this method, 
  // In the occasion that two employees want their funds sent to same address (married couples?)
  // It will only grab the first address associated
  function getEmployeeIndexByAddress(address employeeAddress) internal returns(uint256) {
    for (uint i = 0; i<employees.length; i++) {
        if(employees[i].accountAddress == employeeAddress) return i;
    }
    throw;
  }

  function removeEmployeeIndex(uint index) internal returns(bool) {
      if (index >= employees.length) return;

      for (uint i = index; i<employees.length-1; i++){
          employees[i] = employees[i+1];
      }
      delete employees[employees.length-1];
      employees.length--;
      return true;
    }

    function getERCBalance(address _token) constant returns(uint256) {
      Token ERC20 = Token(address(_token));
      return ERC20.balanceOf(this);
    }

    function transferToken(address _to, address _token, uint256 _amount) internal returns(bool) {
      Token ERC20 = Token(address(_token));
      return ERC20.transfer(_to, _amount);
    }

    function payEmployee(Employee memory employee) internal returns(bool) {
      for(uint i = 0; i < employee.tokens.length; i++) {
        address token = employee.tokens[i];
        uint256 tokenAmountinUSD = (employee.yearlyUSDSalary * employee.distribution[i] / 100);
        uint256 numberOfTokensToSend = (tokenAmountinUSD * 100) / exchangeRates[token];
        require(transferToken(employee.accountAddress, token, numberOfTokensToSend));
      }
    }


    function() payable {
      throw;
    }
}

