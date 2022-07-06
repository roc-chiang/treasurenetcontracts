// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

contract DAO {

    //_status: 1: in progress 2: passed 3: failed
    //_executeStatus: 1: to be executed 2: executed
    event proposalDetail(uint n, address _proposer, string content, string uuid, uint _vote, uint _over, uint _status, uint _executeStatus);
    //_extractStatus: 1: To be extracted 2: Extracted
    event proposalPersonal(uint n, address _voter, uint _voteNow, uint _voteTotal, uint _extractStatus);

    struct proposition{
        address proposer;
        string name;
        string uuid;
        uint voteTotal;
        uint timeOver;
        uint state;
    }
    
    struct voter{
        address voter;
        uint value;
        uint time;
        uint state;
    }

    uint private voteDuration = 10 minutes; 
    proposition[] proposeList;
    mapping(uint => address[]) voterList;
    mapping(uint => mapping(address => bool)) _voter;
    mapping(uint => mapping(address => voter)) vdataList;
    uint voteThreshold = 10**19;

    receive () external payable{}

    //Add resource type proposal
    //name is the name of the resource to be added, and uuid is the details
    function proposal(string memory name, string memory _uuid)public payable returns(bool){
        require(msg.value >= 1000000000000000000, "DAO: value not enough");
        proposition memory propo;
        propo.name = name;
        propo.uuid = _uuid;
        propo.proposer = msg.sender;
        propo.voteTotal = msg.value;
        propo.timeOver = block.timestamp + voteDuration;
        propo.state = 1;
        proposeList.push(propo);

        uint n = proposeList.length-1;

        _voter[n][msg.sender] = true;
        voterList[n].push(msg.sender);

        vdataList[n][msg.sender].voter = msg.sender;
        vdataList[n][msg.sender].time = block.timestamp;
        vdataList[n][msg.sender].state = 1;
        vdataList[n][msg.sender].value = msg.value;

        emit proposalDetail(n, msg.sender, proposeList[n].name, proposeList[n].uuid, proposeList[n].voteTotal, proposeList[n].timeOver, 1, 1);
        emit proposalPersonal(n, msg.sender, msg.value, vdataList[n][msg.sender].value, 1);
        return true;
    }

    //Query all proposals
    function queryPropose()public view returns(proposition[] memory){
        return proposeList;
    }

    //Query the voter of the n th proposal
    function queryVoter(uint n)public view returns(address[] memory){
        return voterList[n];
    }

    //Query the vote amount of the _add address of the n th proposal
    function queryVoteValue(uint n, address _add)public view returns(voter memory){
        return vdataList[n][_add];
    }

    //Query the vote amount of the _add address of the n th proposal
    function queryVoteTotal(uint n)public view returns(uint){
        return proposeList[n].voteTotal;
    }

    function isVoter(uint n, address pAddr)internal view returns(bool){
        return _voter[n][pAddr];
    }

    //Vote for the n th proposal, the value is msg.value
    function voteStart(uint n)public payable returns(bool){
        require(msg.value > 0, "DAO: value must bigger than zero");
        require(proposeList[n].timeOver > block.timestamp, "DAO: vote is over");
        require(proposeList[n].state == 1, "DAO: vote is over");
        if(!isVoter(n,msg.sender)){
            _voter[n][msg.sender] = true;
            voterList[n].push(msg.sender);
            vdataList[n][msg.sender].voter = msg.sender;
            vdataList[n][msg.sender].time = block.timestamp;
            vdataList[n][msg.sender].state = 1;
        }

        vdataList[n][msg.sender].value += msg.value;
        proposeList[n].voteTotal += msg.value;

        if(proposeList[n].voteTotal >= voteThreshold){
            proposeList[n].state = 2;
            emit proposalDetail(n, proposeList[n].proposer, proposeList[n].name, proposeList[n].uuid, proposeList[n].voteTotal, proposeList[n].timeOver, 2, 1);
            emit proposalPersonal(n, msg.sender, msg.value, vdataList[n][msg.sender].value, 1);
        }else{
            emit proposalDetail(n, proposeList[n].proposer, proposeList[n].name, proposeList[n].uuid, proposeList[n].voteTotal, proposeList[n].timeOver, 1, 1);
            emit proposalPersonal(n, msg.sender, msg.value, vdataList[n][msg.sender].value, 1);
        }

        return true;
    }

    //Retrieve the vote amount of the n th vote
    function voteWithdrawal(uint n)public payable returns(bool){
        require(block.timestamp > proposeList[n].timeOver + 1 minutes, "DAO: time limt");
        require(vdataList[n][msg.sender].state == 1, "DAO: state error");
        if(proposeList[n].state == 1){
            proposeList[n].state = 3;
        }
        vdataList[n][msg.sender].state = 2;
        payable(msg.sender).transfer(vdataList[n][msg.sender].value);
        
        emit proposalPersonal(n, msg.sender, 0, vdataList[n][msg.sender].value, 2);
        return true;
    }

    function getThreshold()public view returns(uint){
        return voteThreshold;
    }

}
