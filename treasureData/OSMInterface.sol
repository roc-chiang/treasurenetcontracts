// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface OSMInterface{
    function getCurrencyValue(string memory currency_name) external view returns(uint256);

    function getResourceValue(string memory resourceName, uint Date) external view returns(uint);
}
