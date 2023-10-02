/**
 * Simple Lottery Contract
 * Bets are made in native currency (ETH, BNB, etc)
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Interface for BOG token
interface IBogged {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}


interface IReceivesBogRandV2 {
    function receiveRandomness(bytes32 hash, uint256 random) external;
}

interface IBogRandOracleV2 {
    // Request randomness with fee in BOG
    function getBOGFee() external view returns (uint256);
    function requestRandomness() external payable returns (bytes32 assignedHash, uint256 requestID);

    // Request randomness with fee in BNB
    function getBNBFee() external view returns (uint256);
    function requestRandomnessBNBFee() external payable returns (bytes32 assignedHash, uint256 requestID);
    
    // Retrieve request details
    enum RequestState { REQUESTED, FILLED, CANCELLED }
    function getRequest(uint256 requestID) external view returns (RequestState state, bytes32 hash, address requester, uint256 gas, uint256 requestedBlock);
    function getRequest(bytes32 hash) external view returns (RequestState state, uint256 requestID, address requester, uint256 gas, uint256 requestedBlock);
    // Get request blocks to use with blockhash as hash seed
    function getRequestBlock(uint256 requestID) external view returns (uint256);
    function getRequestBlock(bytes32 hash) external view returns (uint256);

    // RNG backend functions
    function seed(bytes32 hash) external;
    function getNextRequest() external view returns (uint256 requestID);
    function fulfilRequest(uint256 requestID, uint256 random, bytes32 newHash) external;
    function cancelRequest(uint256 requestID, bytes32 newHash) external;
    function getFullHashReserves() external view returns (uint256);
    function getDepletedHashReserves() external view returns (uint256);
    
    // Events
    event Seeded(bytes32 hash);
    event RandomnessRequested(uint256 requestID, bytes32 hash);
    event RandomnessProvided(uint256 requestID, address requester, uint256 random);
    event RequestCancelled(uint256 requestID);
}

interface IPancakeRouter01 {
    function WETH() external pure returns (address);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
}

interface IPancakeRouter is IPancakeRouter02 {}

contract Lottery is Ownable,IReceivesBogRandV2 {    
    uint256 public ENTRY_INCREMENT = 1 * 10 ** 16; // entries must be in .01 BNB increments, adjustable
    uint256 public MAXIMIUM_POOL_SIZE = 100 * 10 ** 18; // 100 BNB max pool size, adjustable
    uint256 public MAXIMUM_ENTRIES = 5000; // 5000 entrants max as a precaution, adjustable
        
    struct Winner {
        address playerAddress;
        uint256 bnbAmount;
    }
    
    event WinnerResult(
        address indexed winner,
        uint256 indexed totalStake
    );
    
    event WaitingForRandom();
    
    enum LOTTERY_STATE { OPEN, PICKING_WINNER, WAITING_RANDOM, REWARDING_WINNER, CLOSED }
    LOTTERY_STATE public lotteryState;
    
    // ADDRESSES
    address private MARKETING_ADDRESS = YOUR_WALLET_HERE;
    address private constant oracleAddress = 0xe308d2B81e543b21c8E1D0dF200965a7349eb1b7;

    address[] private players;
    uint256 private numPlayers;
    Winner[] private winners;
    uint256 private openTimestamp;
    uint256 private lotteryPoolSize;

    // LOTTERY TIME VALUES
    uint256 public LOTTERY_RUN_TIME = 10 * 60; // minutes * seconds [adjustable]

    // BogRNG Oracle
    IBogRandOracleV2 private rng;
    uint256 private random;
    uint256 public MAXIMUM_ORACLE_FEE = 3 * 10 ** 16; // .03 BNB maximum fee for oracle call, safety check
    uint256 public EXTRA_GAS_FEE = 15 * 10 ** 14;     // 300k gas, assuming 5 GWEI as gas price
    uint256 private ORACLE_WAIT_TIME = 60 * 60 * 2;   // 2 hours in seconds
    bool public oracleDoReward = true;
    
    constructor() {
        rng = IBogRandOracleV2(oracleAddress);
        
        resetPool();
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    /**
     * Reset lottery pool. Lottery state should be set to CLOSED right after.
     */
    function resetPool() private {
        clearPlayers();
        lotteryPoolSize = 0;
        random = 0;
    }
    
    function openLottery() public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "LotteryState must be CLOSED to OPEN.");
        lotteryState = LOTTERY_STATE.OPEN;
        openTimestamp = block.timestamp;
    }
    
    function updateEntryConstants(uint maxPoolSize, uint maxEntries) public onlyOwner {
        if (maxPoolSize > 0) {
            MAXIMIUM_POOL_SIZE = maxPoolSize;
        }
        if (maxEntries > 0) {
            MAXIMUM_ENTRIES = maxEntries;
        }
    }
    
    function updateEntryIncrement(uint increment) public onlyOwner {
        require(increment > 0, "increment must be greater than 0.");
        ENTRY_INCREMENT = increment;
    }
    
    function updateMaxOracleFee(uint fee) public onlyOwner {
        require(fee > 0, "Max Oracle fee must be greater than 0.");
        MAXIMUM_ORACLE_FEE = fee;
    }
    
    function updateExtraGasFee(uint fee) public onlyOwner {
        require(fee > 0, "Extra gas fee must be greater than 0.");
        EXTRA_GAS_FEE = fee;
    }
    
    function updateLotteryRunTime(uint runtime) public onlyOwner {
        require(runtime > 0, "Runtime must be greater than 0.");
        LOTTERY_RUN_TIME = runtime;
    }
    
    function updateOracleDoReward(bool doReward) public onlyOwner {
        oracleDoReward = doReward;
    }

    function updateFeeAddress(address payable _feeAddress) public onlyOwner {
        MARKETING_ADDRESS = _feeAddress;
    }

    function withdrawStuckBNB(uint256 amount) public onlyOwner {
        if (amount == 0) payable(owner()).transfer(address(this).balance);
        else payable(owner()).transfer(amount);
    }

    function withdrawStuckTokens(address token) public onlyOwner {
        IERC20(address(token)).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }
    
    /**
     * Helper function to avoid expensive array deletion
     */
    function addPlayer(address player) private {
        assert(numPlayers <= players.length);
        if (numPlayers == players.length) {
            players.push(player);
        } else {
            players[numPlayers] = player;
        }
        numPlayers++;
    }
    
    /**
     * Helper function to avoid expensive array deletion
     */
    function clearPlayers() private {
        numPlayers = 0;
    }
    
    /**
     * Enter the lottery.
     * The caller must have approved this contract to spend tokens in advance.
     * This can cause a state transition to PICKING_WINNER if the current timestamp passes the lottery run time.
     */
    function enter(uint256 amount_) external {
        require(lotteryState == LOTTERY_STATE.OPEN, "The lottery is not open.");
        require(lotteryPoolSize < MAXIMIUM_POOL_SIZE, "The lottery has reached max pool size.");
        require(players.length <= MAXIMUM_ENTRIES, "The lottery has reached max number of entries.");
        
        // restrict to entry increments to prevent massive arrays
        require(amount_ >= ENTRY_INCREMENT, "Entry amount less than minimum.");
        require(amount_ % ENTRY_INCREMENT == 0, "Entry must be in increments of ENTRY_INCREMENT.");
        
        //require(tokenContract.transferFrom(msg.sender, address(this), amount_), "Failed to transfer tokens from your address.");
        
        for (uint i = 0; i < amount_ / ENTRY_INCREMENT; i++) {
            addPlayer(msg.sender);
        }
        
        lotteryPoolSize = lotteryPoolSize + amount_;
        
        if (block.timestamp > openTimestamp + LOTTERY_RUN_TIME) {
            lotteryState = LOTTERY_STATE.PICKING_WINNER;
            pickWinner();
        }
    }
    
    /**
     * Pick the winner by requesting a random number.
     * The PICKING_WINNER state can be triggered by enter() or by calling pickWinner() directly.
     * This method calls the BogRNG Oracle to generate a new random number. rewardWinner() must be called
     * manually after the BogRNG Oracle supplies the random number.
     */
    function pickWinner() public {
        if (lotteryState == LOTTERY_STATE.OPEN && block.timestamp > openTimestamp + LOTTERY_RUN_TIME) {
            lotteryState = LOTTERY_STATE.PICKING_WINNER;
        }
        require(lotteryState == LOTTERY_STATE.PICKING_WINNER, "The lottery is not picking winner.");
        uint256 fee = rng.getBNBFee();
        require(address(this).balance > fee, "Contract address needs more BNB for oracle fee.");
        
        // Do not allow state transition to WAITING_RANDOM if no players
        if (numPlayers == 0) {
            resetPool();
            lotteryState = LOTTERY_STATE.CLOSED;
            return;
        }
        
        refreshRandomNumber(fee);
        emit WaitingForRandom();
        lotteryState = LOTTERY_STATE.WAITING_RANDOM;
    }
    
    /**
     * Refresh the random number by requesting a new random number from the BogRNG oracle
     */
    function refreshRandomNumber(uint256 fee) private {
        uint256 extraFee = fee + EXTRA_GAS_FEE;
        require(extraFee < MAXIMUM_ORACLE_FEE, "Oracle fee too high. Adjust contract limits.");
        rng.requestRandomnessBNBFee{value: extraFee}();
    }
    
    /**
     * Randomness callback function by the BogRNG oracle
     */
    function receiveRandomness(bytes32 hash_, uint256 random_) external override {
        require(msg.sender == address(rng)); // Ensure the sender is the oracle

        // lottery already received a random number (maybe an override), ignore callback
        if (lotteryState != LOTTERY_STATE.WAITING_RANDOM) {
            return;
        }
        
        random = random_; // Store random number
        
        lotteryState = LOTTERY_STATE.REWARDING_WINNER;
        // Be wary of max gas usage of BogRNG Oracle callback.
        if (oracleDoReward) {
            rewardWinner();
        }
    }
    
    /**
     * Fallback mechanism if BogRNG oracle has not called back after a 2 hour waiting period or if callback fails for other reason.
     * This is not ideal, but the winning index is a hash of supplied random, block.timestamp, and block.difficulty.
     * This should be sufficiently difficult to game. Contract owner cannot predict exact timestamp/difficulty,
     * and miners can't predict the supplied random.
     * TODO: a decentralized way of handling this scenario
     */
    function receiveRandomnessOverride(uint256 random_) external onlyOwner {
        require(lotteryState == LOTTERY_STATE.WAITING_RANDOM, "Lottery is not waiting for a random number.");
        // wait 2 hours minimum for oracle callback
        require(block.timestamp > openTimestamp + LOTTERY_RUN_TIME + ORACLE_WAIT_TIME, "Minimum wait time for Oracle not met.");
        
        random = random_; // Store random number
        
        lotteryState = LOTTERY_STATE.REWARDING_WINNER;
    }
    
    /**
     * Select and reward the winner.
     * This can only be executed after the BogRNG Oracle has called back to receiveRandomness().
     */
    function rewardWinner() public {
        require(lotteryState == LOTTERY_STATE.REWARDING_WINNER, "The lottery is not rewarding winner.");

        // 256 bit wide result of keccak256 is always greater than the number of players
        uint index = uint256(keccak256(abi.encodePacked(random, block.timestamp, block.difficulty))) % numPlayers;

        address winningAddress = players[index];
        
        // Send 10% of the winning pool to marketing wallet
        uint contractBalance = address(this).balance;
        payable(MARKETING_ADDRESS).transfer(contractBalance / 10);
        
        // Send remaining pool to winner
        contractBalance = address(this).balance;
        payable(winningAddress).transfer(contractBalance);
        
        // Winning address and pool amount saved
        winners.push(Winner(winningAddress, contractBalance));
        emit WinnerResult(winningAddress, contractBalance);
        
        resetPool();
        lotteryState = LOTTERY_STATE.CLOSED;
    }
    
    event Received(address, uint);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    function getNumPlayers() public view returns (uint256) {
        return numPlayers;
    }
    
    function getPlayers() public view returns (address[] memory) {
        return players;
    }
    
    function getWinners() public view returns (Winner[] memory) {
        return winners; // historical winners
    }
    
    function getLotteryPoolSize() public view returns (uint256) {
        return lotteryPoolSize;
    }
    
    function getWinningPoolSize() public view returns (uint256) {
        return address(this).balance;
    }
    
    function getOpenTimestamp() public view returns (uint256) {
        return openTimestamp;
    }
}