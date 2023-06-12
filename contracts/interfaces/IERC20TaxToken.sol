//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "./IERC20.sol";


interface IERC20TaxToken is IERC20 {
    function _taxFee() external view returns (uint256);

}
