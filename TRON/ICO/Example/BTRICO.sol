pragma solidity ^0.4.25;

import './BTRBaseToken.sol';



contract ICO is BaseToken{

    uint256 base = 10;
    uint256 multiplier;

    address ownerMultisig;

    struct ICOPhase {
        string phaseName;
        uint256 tokensStaged;
        uint256 tokensAllocated;
       
        uint256 RATE;
        bool saleOn;
        uint deadline;
    }

    uint8 public currentICOPhase;
    
    mapping(address=>uint256) public trxContributedBy;
    uint256 public totalTrxRaised;
    uint256 public totalTokensSoldTillNow;

    mapping(uint8=>ICOPhase) public icoPhases;
    uint8 icoPhasesIndex=1;
    
    function getTrxContributedBy(address _address) view public returns(uint256){
        return trxContributedBy[_address];
    }

    function getTotalTrxRaised() view public returns(uint256){
        return totalTrxRaised;
    }

    function getTotalTokensSoldTillNow() view public returns(uint256){
        return totalTokensSoldTillNow;
    }

    
    function addICOPhase(string _phaseName,uint256 _tokensStaged,uint256 _rate) ownerOnly public{
        icoPhases[icoPhasesIndex].phaseName = _phaseName;
        icoPhases[icoPhasesIndex].tokensStaged = _tokensStaged;
       
        icoPhases[icoPhasesIndex].RATE = _rate;
        
        
        icoPhases[icoPhasesIndex].tokensAllocated = 0;
        icoPhases[icoPhasesIndex].saleOn = false;
       // icoPhases[icoPhasesIndex].tokensStaged = tokensAllocated;

        icoPhasesIndex++;
    }

    function toggleSaleStatus() ownerOnly external{
        icoPhases[currentICOPhase].saleOn = !icoPhases[currentICOPhase].saleOn;
    }
    function changeRate(uint256 _rate) ownerOnly external{
        icoPhases[currentICOPhase].RATE = _rate;
    }
    function changeCurrentICOPhase(uint8 _newPhase) ownerOnly external{ //Only provided for exception handling in case some faulty phase has been added by the owner using addICOPhase
        currentICOPhase = _newPhase;
    }

  /*  function changeCurrentPhaseDeadline(uint8 _numdays) ownerOnly external{
        icoPhases[currentICOPhase].deadline= addDaystoTimeStamp(_numdays); //adds number of days to now and that becomes the new deadline
    }*/
    
    function transferOwnership(address newOwner) ownerOnly external{
        if (newOwner != address(0)) {
          owner = newOwner;
        }
    }
    
}
