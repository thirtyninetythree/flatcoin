// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts@4.3.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.3.2/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

contract FlatCoin is ERC20, Ownable, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    //REFERENCE_INDEX = avg(brent + gold+ sugar)
    // 0.0098241067923047 + 0.056803632236095 + 0.0005268111589

    uint256 public immutable REFERENCE_INDEX = 0.06715455018 * 10 ** 18;
    uint256 public currentIndex;
    
    uint256 public BRENTOIL_PRICE;
    uint256 public SUGAR_PRICE;
    uint256 public GOLD_PRICE;
    
    event Log(string message, uint256 amount);
    event Rebalancing(string message);
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Kovan
     * Aggregator: ETH/USD
     * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
     */
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    
    constructor() ERC20("StableCoin", "Stable") {
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        
        setPublicChainlinkToken();
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
        requestBrentOilPrice();
        requestSugarPrice();
        requestGoldPrice();
    }

    function mint(address _to, uint256 _amount) public payable {
        currentIndex = BRENTOIL_PRICE + SUGAR_PRICE + GOLD_PRICE;
        currentIndex = currentIndex/referenceIndex;
        require(msg.value * uint256(getLatestETHPrice()) < (1 + currentIndex) * _amount, "Too little collateral");
        emit Log("ETH PRICE: ", msg.value * uint256(getLatestETHPrice()));
        emit Log("Stable minted:", currentIndex * _amount);
        _mint(_to, _amount);
    }
    
    function burn(uint256 _amount) public payable {
        //burns sstables and returns collateral
        uint256 valueInUSD = _amount * currentIndex/referenceIndex;
        uint256 valueInETH = valueInUSD/uint256(getLatestETHPrice());
        
        (bool os, ) = payable(msg.sender).call{value: valueInETH }("");
            require(os);
        emit Log("Collateral redeemed:", currentIndex * _amount);
    }

    function getFlatCoinPrice() public view returns(uint) {
        return totalSupply()/address(this).balance;
    }
    
    function requestBrentOilPrice() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillBrentOilPrice.selector);
        // Set the URL to perform the GET request on
        request.add("get", "https://commodities-api.com/api/latest?access_key=<YOUR KEY>");
       
        request.add("path", "data.rates.BRENTOIL");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
     /**
     * Receive the response in the form of uint256
     */ 
    function fulfillBrentOilPrice(bytes32 _requestId, uint256 _BRENTOIL) public recordChainlinkFulfillment(_requestId){
        BRENTOIL_PRICE = _BRENTOIL;
    }

    function requestSugarPrice() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillSugarPrice.selector);
        // Set the URL to perform the GET request on
        request.add("get", "https://commodities-api.com/api/latest?access_key=<YOUR KEY>");
       
        request.add("path", "data.rates.SUGAR");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
     /**
     * Receive the response in the form of uint256
     */ 
    function fulfillSugarPrice(bytes32 _requestId, uint256 _SUGAR) public recordChainlinkFulfillment(_requestId){
        SUGAR_PRICE = _SUGAR;
    }

    function requestGoldPrice() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillGoldPrice.selector);
        // Set the URL to perform the GET request on
        request.add("get", "https://commodities-api.com/api/latest?access_key=<YOUR KEY>");
       
        request.add("path", "data.rates.XAU");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
     /**
     * Receive the response in the form of uint256
     */ 
    function fulfillGoldPrice(bytes32 _requestId, uint256 _GOLD) public recordChainlinkFulfillment(_requestId){
        GOLD_PRICE = _GOLD;
    }

    /**
     * Returns the latest ETH  price
     */
    function getLatestETHPrice() public view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }
}
