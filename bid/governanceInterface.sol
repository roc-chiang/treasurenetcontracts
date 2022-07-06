// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface governanceInterface{

    /* get USP reserve ratio */
    function getUSTNReserveRatio() view external returns (uint amount);

    function getMarginRatio() view external returns (uint amount);

    /* get USP loan daily interest rate */
    function getUSTNLoanInterestRate() view external returns (uint amount);

    /* get USP loan pledge rate */
    function getUSTNLoanPledgeRate() view external returns (uint amount);

    /* get USP loan pledge rate warning value */
    function getUSTNLoanPledgeRateWarningValue() view external returns (uint amount);

    /* get USP loan liquidation rate */
    function getUSTNLoanLiquidationRate() view external returns (uint amount);

    function checkTargetSenderContractGroup(string memory name, address contractAddress) view external returns (bool result);

    function checkProducerAddress(address sender) view external returns (bool);

    function getAddress(string memory name)external view returns(address);

    function checkUWIOwnerAddress(string memory UWI, address account) view external returns (bool result);

    function getUWI(address account, string memory location_id, string memory location) view external returns (string memory UWI);

    function getPriceDiscount(address account, string memory UWI) view external returns (uint discount);

    function checkTargetSenderGroup(string memory level, address targetSender) view external returns (bool result);

    function getMinerAddress(address account, string memory name)external view returns(address);
}
