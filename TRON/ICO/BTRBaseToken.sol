pragma solidity ^0.4.25;
import './F_SafeMath.sol';

contract TRC20 {
    function totalSupply() view public returns (uint _totalSupply);
    function balanceOf(address _owner) view public returns (uint balance);
    function transfer(address _to, uint _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint _value) public returns (bool success);
    function approve(address _spender, uint _value) public returns (bool success);
    function allowance(address _owner, address _spender) view public returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}


contract BaseToken is TRC20 {
    
    address public owner;
    using SafeMath for uint256;
    
    bool public tokenStatus = false;
    
    modifier ownerOnly(){
        require(msg.sender == owner);
        _;
    }

    
    modifier onlyWhenTokenIsOn(){
        require(tokenStatus == true);
        _;
    }


    function onOff () ownerOnly external{
        tokenStatus = !tokenStatus;    
    }
   
    /**
       * @dev Fix for the TRC20 short address attack.
    */
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }    
    mapping (address => uint256) public balances;
    mapping(address => mapping(address => uint256)) allowed;

    //Token Details
    string public symbol = "BTR";
    string public name = "Blocktorial";
    uint8 public decimals = 9;

    uint256 public totalSupply; //will be instantiated in the derived Contracts
    
  function msgTokenValueAndTokenIdTest() public payable returns(trcToken, uint256){
        trcToken id = msg.tokenid;
        uint256 value = msg.tokenvalue;
        return (id, value);
    }


function getTokenBalance(address accountAddress) payable public returns (uint256){
        trcToken id = 1000686;
        return accountAddress.tokenBalance(id);
    }
   
    
    function transfer(address _to, uint _value) onlyWhenTokenIsOn onlyPayloadSize(2 * 32) public returns (bool success){
        //_value = _value.mul(1e18);
        require(
            balances[msg.sender]>=_value 
            && _value > 0);
            balances[msg.sender] = balances[msg.sender].sub(_value);
            balances[_to] = balances[_to].add(_value);
            emit  _to.transferToken(_value,1000686);
            return true;
    }
    
    function transferFrom(address _from, address _to, uint _value) onlyWhenTokenIsOn onlyPayloadSize(3 * 32) public returns (bool success){
        //_value = _value.mul(10**decimals);
        require(
            allowed[_from][msg.sender]>= _value
            && balances[_from] >= _value
            && _value >0 
            );
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit _to.Transfer(_from, _to, _value,1000686);
        return true;
            
    }
    
    function approve(address _spender, uint _value) onlyWhenTokenIsOn public returns (bool success){
        //_value = _value.mul(10**decimals);
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) view public returns (uint remaining){
        return allowed[_owner][_spender];
    }

    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    

}
