#pragma version ^0.4.0

from ethereum.ercs import IERC20

struct UserInfo:
    amount: uint256 
    authorized: bool

payers: public(DynArray[address, 25])
admin: public(address)
asset: public(IERC20)
contribution: public(HashMap[address, UserInfo])
total_owed: public(uint256)
active: public(bool)
receiver: public(address)

# function to calculate liability for each participant based on total_owed for the group
# function to pay in 
# conditional rage quit allowed ???
# function to refund users that "overpaid" based on individual burden function
# this can only happen AFTER total is paid

@deploy
def __init__(admin: address, asset: address, payers: DynArray[address, 25], total_owed: uint256, receiver: address):
    assert len(payers) > 0, "No payers added"
    assert total_owed >= 4, "Too small to split"
    self.payers = payers
    self.admin = admin
    self.asset = IERC20(asset)
    self.total_owed = total_owed
    self.receiver = receiver
    self.active = True
    for p: address in payers:
        assert self.contribution[p].authorized == False, "All payers must be unique"
        self.contribution[p].authorized = True

@payable
@external
def contribute():
    contributed: uint256 = self.contribution[msg.sender].amount
    owed_pp: uint256 = self.amount_owed_per_person()
    assert self.active == True, "Split is inactive"
    assert owed_pp >= contributed, "Already paid"
    assert self.contribution[msg.sender].authorized == True, "Not an authorized payer for this split"
    personal_owed: uint256 = owed_pp - contributed
    if self.asset == IERC20(empty(address)): 
        self.contribution[msg.sender].amount += msg.value
        assert msg.value >= personal_owed, "Failed to contribute funds"
    else: 
        old_bal: uint256 = staticcall self.asset.balanceOf(self)
        res: bool = extcall self.asset.transferFrom(msg.sender, self, personal_owed, default_return_value=True)
        assert res == True, "Failed to contribute funds"
        new_bal: uint256 = staticcall self.asset.balanceOf(self)
        self.contribution[msg.sender].amount = new_bal - old_bal

@external
def add_payer(addy: address):
    assert msg.sender == self.admin, "Caller is not the admin of this split"
    assert self.contribution[addy].authorized == False, "Payer already exists"
    self.payers.append(addy)
    self.contribution[addy].authorized = True

@external
def execute_payment():
    amount: uint256 = self.total_owed
    assert msg.sender == self.admin, "Caller is not the admin of this split"
    assert self.active == True, "Already concluded"
    for payer: address in self.payers:
        assert self.contribution[payer].amount >= self.amount_owed_per_person(), "Insufficient Payment"
        self.contribution[payer].amount -= self.amount_owed_per_person()
    self.active = False
    if self.asset == IERC20(0x0000000000000000000000000000000000000000): 
        send(self.receiver, self.total_owed)
    else: 
        res: bool = extcall self.asset.transfer(self.receiver, amount, default_return_value=True)
        assert res == True, "Failed to process refund"

@external 
def exit_pool(): 
    assert self.active == True, "Split is inactive"
    contributed: uint256 = self.contribution[msg.sender].amount
    self.contribution[msg.sender].amount -= contributed
    if self.asset == IERC20(0x0000000000000000000000000000000000000000): 
        send(msg.sender, contributed)
    else: 
        res: bool = extcall self.asset.transfer(msg.sender, contributed, default_return_value=True)
        if res == False: 
            raise "Failed to process refund"
   
@external
def refund_overpayment(): 
    # Invariant: AmountOwed % len(payers) == 0
    refund: uint256 = self.contribution[msg.sender].amount
    if self.total_owed % len(self.payers) != 0:
        refund -= len(self.payers) - (self.total_owed % len(self.payers))
    assert self.active == False, "Split is active"
    self.contribution[msg.sender].amount -= refund
    if self.asset == IERC20(0x0000000000000000000000000000000000000000): 
        send(msg.sender, refund)
    else: 
        res: bool = extcall self.asset.transfer(msg.sender, refund, default_return_value=True)
        assert res == True, "Failed to process refund"

@view
def amount_owed_per_person() -> uint256:
    return self.total_owed // len(self.payers)
