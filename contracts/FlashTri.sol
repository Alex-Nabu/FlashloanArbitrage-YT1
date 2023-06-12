//SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "hardhat/console.sol";

// import "./interfaces/Uniswap.sol";
import "./libraries/SafeMath.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IERC20TaxToken.sol";
import "./Ownable.sol";

pragma solidity >=0.6.6;
// import "./interfaces/Uniswap.sol";
contract ContractFlashTri is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // bases we can use to fetch a flashloan seperate from our arb
    address public dummyBase1 = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // WBNB
    address public dummyBase2 = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT
    address public dummyBase3 = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // USDC
    address public dummyBase4 = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // WETH

    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // Trade Struct
    struct TradeDetails {
        address factoryT1;
        address factoryT2;
        address factoryT3;
        address routerT1;
        address routerT2;
        address routerT3;
        address tokenA;
        address tokenB;
        address tokenC;
    }

    // Trade Mapping
    mapping(address => TradeDetails) public tradeDetails;

    event taxContract(uint256 tax, uint256 loanAmount, uint256 minusTax);

    // FUND SWAP CONTRACT
    // Provides a runction to allow contract to be funded
    function fundFlashSwapContract(
        address _owner,
        address _token,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    // GET CONTRACT BALANCE
    // Allows public view of balance for contract
    function getBalanceOfToken(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    // PLACE A TRADE
    // Executes placing a trade
    function placeTrade(
        string memory _tradeInfo,
        address _factory,
        address _router,
        address _fromToken,
        address _toToken,
        uint256 _amountIn
    ) private returns (uint256) {
        address pair = IUniswapV2Factory(_factory).getPair(
            _fromToken,
            _toToken
        );

        string memory noPool = string(abi.encodePacked("Pool does not exist : ", _tradeInfo));
        require(pair != address(0), noPool);

        // Perform Arbitrage - Swap for another token on Uniswap
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRequired = IUniswapV2Router01(_router).getAmountsOut(
            _amountIn,
            path
        )[1];

        uint256 deadline = block.timestamp + 30 minutes;

        uint256 amountReceived = IUniswapV2Router01(_router)
            .swapExactTokensForTokens(
                _amountIn, // amountIn
                amountRequired, // amountOutMin
                path, // contract addresses
                address(this), // address to
                deadline // block deadline
            )[1];

        // Return output
        require(amountReceived > 0, "Aborted Tx: Trade returned zero");
        return amountReceived;
    }

    // CHECK PROFITABILITY
    // Checks whether output > input
    function checkProfitability(uint256 _input, uint256 _output)
        private
        pure
        returns (bool)
    {
        return _output > _input;
    }

    // INITIATE ARBITRAGE
    // Begins the arbitrage for receiving a Flash Loan
    function triangularArbitrage(
        address[3] calldata _factories,
        address[3] calldata _routers,
        address[3] calldata _tokens,
        uint256 _amountBorrow
    ) external {
        // Approve contract to make transactions
        if (_routers[0] == _routers[1] && _routers[1] == _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[0]), MAX_INT);
        } else if (_routers[0] == _routers[1] && _routers[1] != _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[2]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[2]), MAX_INT);
        } else if (_routers[0] != _routers[1] && _routers[1] == _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[0]).approve(address(_routers[1]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[1]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[1]), MAX_INT);
        } else if (_routers[0] != _routers[1] && _routers[1] != _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[1]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[1]), MAX_INT);
        }

        // Assign dummy token change if needed
        address dummyToken;
        if (_tokens[0] != dummyBase1 && _tokens[1] != dummyBase1 && _tokens[2] != dummyBase1) {
            dummyToken = dummyBase1;
        } else if (
            _tokens[0] != dummyBase2 && _tokens[1] != dummyBase2 && _tokens[2] != dummyBase2
        ) {
            dummyToken = dummyBase2;
        } else if (
            _tokens[0] != dummyBase3 && _tokens[1] != dummyBase3 && _tokens[2] != dummyBase3
        ) {
            dummyToken = dummyBase3;
        } else {
            dummyToken = dummyBase4;
        }

        // Get Factory pair address for combined tokens
        address pair = IUniswapV2Factory(_factories[0]).getPair(
            _tokens[0],
            dummyToken
        );
        require(pair != address(0), "Dummy flash Pool does not exist");

        // Figure out which token (0 or 1) has the amount and assign
        // Assumes borrowing tokenA
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amount0Out = _tokens[0] == token0 ? _amountBorrow : 0;
        uint256 amount1Out = _tokens[0] == token1 ? _amountBorrow : 0;

        // Passing data triggers pancakeCall as this is what constitutes a loan
        // TokenA is the token being borrowed
        bytes memory data = abi.encode(_tokens[0], _amountBorrow, msg.sender);

        // Save trade data to tradeDetails mapping
        tradeDetails[msg.sender] = TradeDetails(
            _factories[0],
            _factories[1],
            _factories[2],
            _routers[0],
            _routers[1],
            _routers[2],
            _tokens[0],
            _tokens[1],
            _tokens[2]
        );

        // Execute the initial swap with the loan
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    // RECEIVE LOAN AND EXECUTE TRADES
    // This function is called from the .swap in startArbitrage if there is byte data
    function _uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) internal {
        // Decode data for calculating repayment
        (address tokenA, uint256 amountBorrow, address sender) = abi.decode(
            _data,
            (address, uint256, address)
        );

        // Ensure this request came from the contract
        address pair;
        {
            address token0 = IUniswapV2Pair(msg.sender).token0();
            address token1 = IUniswapV2Pair(msg.sender).token1();
            pair = IUniswapV2Factory(tradeDetails[sender].factoryT1)
                .getPair(token0, token1);
            require(msg.sender == pair, "The sender needs to match the pair");
            require(_sender == address(this), "Sender should match this contract");
        }


        // Calculate amount to repay at the end
        uint256 fee = ((amountBorrow * 3) / 997) + 1;
        uint256 amountToRepay = amountBorrow + fee;

        // Extract amount of acquired token going into next trade
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        // some trade info we'll increment as we go ahead
        //string memory placeTradeInfo = "1";

        // Trade 1
        uint256 trade1AcquiredCoin = placeTrade(
            "P1",
            tradeDetails[sender].factoryT1,
            tradeDetails[sender].routerT1,
            tradeDetails[sender].tokenA,
            tradeDetails[sender].tokenB,
            loanAmount
        );


        // Trade 2
        uint256 trade2AcquiredCoin = placeTrade(
            "P2",
            tradeDetails[sender].factoryT2,
            tradeDetails[sender].routerT2,
            tradeDetails[sender].tokenB,
            tradeDetails[sender].tokenC,
            trade1AcquiredCoin
        );

        // Trade 3
        uint256 trade3AcquiredCoin = placeTrade(
            "P3",
            tradeDetails[sender].factoryT3,
            tradeDetails[sender].routerT3,
            tradeDetails[sender].tokenC,
            tradeDetails[sender].tokenA,
            trade2AcquiredCoin
        );

        // Profit check
        bool profCheck = checkProfitability(loanAmount, trade3AcquiredCoin);
        require(profCheck, "Arbitrage not profitable");

        // Pay yourself back first
        IERC20 otherToken = IERC20(tradeDetails[sender].tokenA);
        otherToken.transfer(sender, trade3AcquiredCoin - amountToRepay);

        // Pay loan back
        // TokenA as borrowed token
        IERC20(tokenA).transfer(pair, amountToRepay);
    }


    // withdraw all of specified token can only be called by owner
    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
    IERC20 tokenContract = IERC20(_token);

    // transfer the token from address of this contract
    // to address of the user (executing the withdrawToken() function)
    tokenContract.transfer(msg.sender, _amount);
    }

    // makes so can send back our eth
    function withdrawEth() external onlyOwner {
      payable(msg.sender).transfer(address(this).balance);
    }

    // makes so can accept randomly sent eth
    receive() external payable {}


    // set the base tokens we use to fetch a pool for our flashloan
    function setBases(address[4] calldata dummyBases) external onlyOwner {
        dummyBase1 = dummyBases[0];
        dummyBase2 = dummyBases[1];
        dummyBase3 = dummyBases[2];
        dummyBase4 = dummyBases[3];
    }

    //@notice Function is called by the Uniswap V2 pair's `swap` function
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data ) external {
        _uniswapV2Call(sender, amount0, amount1, data);
    }

    // same as uniV2Call but for pancake clones
    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        _uniswapV2Call(_sender, _amount0, _amount1, _data);
    }

    // same as uniV2Call but for pancake clones
    function apeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        _uniswapV2Call(_sender, _amount0, _amount1, _data);
    }

}
