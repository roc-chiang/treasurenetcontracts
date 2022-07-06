// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;
import "governanceInterface.sol";

contract OSM{        

    struct ResourceType{
        uint Date;
        uint Value;
        uint timestamp;
    }
    
    mapping(string => ResourceType[]) resourceTypes;
    mapping(string => uint256) currencyValue;
    mapping(string => mapping(uint => uint)) resourceValue;

    governanceInterface verifyAddress;

    constructor(address governanceAddress) {
        verifyAddress = governanceInterface(governanceAddress);
        currencyValue["USTN"]= 1;
        currencyValue["UNIT"]= 10;
    }
    
    modifier onlyUser(string memory name){
        require(verifyAddress.checkTargetSenderGroup(name, msg.sender), "OSM: Only authority user can use this interface.");
        _;
    }

    function setGovernanceContract(address contractAddress) public onlyUser("FoundationManager") returns(bool) {
        verifyAddress = governanceInterface(contractAddress);
        return true;
    }
    
    //set resource name and value
    function setResourceValue(string memory resourceName, uint Date, uint Value) public onlyUser("Feeder") returns(bool){
        require(Value > 0, "OSM :value must bigger than 0");
        ResourceType memory resource_type;
        resource_type.Date = Date;
        resource_type.Value = Value;
        resource_type.timestamp = block.timestamp;
        resourceTypes[resourceName].push(resource_type);
        resourceValue[resourceName][Date] = Value;
        return true;
    }

    //get resource data information of history
    function getResourceData(string memory resourceName) public view returns(ResourceType[] memory){
        return resourceTypes[resourceName];
    }

    //get resource value
    function getResourceValue(string memory resourceName, uint Date) public view returns(uint){
        if(resourceValue[resourceName][Date] != 0){
            return(resourceValue[resourceName][Date]);
        }else{
            uint total = 0;
            uint n = resourceTypes[resourceName].length;
            if(resourceTypes[resourceName].length >= 10){
                for(uint i = 10; i>0;i--){
                    total += resourceTypes[resourceName][n-1].Value;
                    n--;
                }
                return total/10;              
            }else{
                for(n;n>0;n--){
                    total += resourceTypes[resourceName][n-1].Value;
                }
                return total/resourceTypes[resourceName].length;
            }
        }
    }
    
    //set currency name and value 
    function setCurrencyValue(string memory currencyName, uint256 value)public onlyUser("Feeder") returns(bool){
        require(value > 0, "OSM: value must bigger than 0");
        currencyValue[currencyName]= value;
        return true;
    }
    
    //get currency value
    function getCurrencyValue(string memory currencyName)public view returns(uint256){
        return currencyValue[currencyName];
    }

}
