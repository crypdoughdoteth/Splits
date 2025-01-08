import boa
import pytest
from hypothesis import given
from hypothesis.strategies import lists
from boa.test import strategy


@pytest.mark.gas
def test_ether():
    contract = boa.load(
        "contracts/Split.vy",
        boa.env.eoa,
        "0x0000000000000000000000000000000000000000",
        [boa.env.eoa],
        1000000000000000000,
        boa.env.eoa,
    )
    # first and only position should be our eoa
    assert contract.payers(0) == boa.env.eoa
    # amount owed for 1 person is full amount
    assert contract.internal.amount_owed_per_person() == 1000000000000000000
    boa.env.set_balance(boa.env.eoa, 10000000000000000000)
    # inital donation
    contract.contribute(value=1000000000000000000)
    # early refund / exit
    contract.exit_pool()
    # check to see if contribution is zeroed out in state
    assert contract.contribution(boa.env.eoa)[0] == 0
    contract.contribute(value=2000000000000000000)
    contract.execute_payment()
    # contract isn't active
    assert not contract.active()
    contract.refund_overpayment()
    # paid the receiver
    assert boa.env.get_balance(boa.env.eoa) == 10000000000000000000


@pytest.mark.gas
def test_token():
    token = boa.load("tests/erc20.vy", "Testing", "TEST", 18, 100000000)
    assert token.balanceOf(boa.env.eoa) == 100000000 * (10**18)
    contract = boa.load(
        "contracts/Split.vy",
        boa.env.eoa,
        token.address,
        [boa.env.eoa],
        1000000000000000000,
        boa.env.eoa,
    )
    token.approve(contract.address, 2000000000000000000)
    contract.contribute()
    contract.exit_pool()
    assert contract.contribution(boa.env.eoa)[0] == 0
    contract.contribute()
    contract.execute_payment()
    assert not contract.active()
    assert token.balanceOf(boa.env.eoa) == 100000000 * (10**18)


@pytest.mark.gas
@given(
    a=strategy("uint256", max_value=2**64, min_value=100),
    b=lists(strategy("address"), max_size=24, unique=True).filter(lambda x: len(x) > 0),
)
def test_multiple(a, b):
    token = boa.load("tests/erc20.vy", "Testing", "TEST", 18, a * len(b) + 1)
    for addy in b:
        token.transfer(addy, a)
    contract = boa.load(
        "contracts/Split.vy",
        boa.env.eoa,
        token.address,
        [boa.env.eoa],
        a,
        boa.env.eoa,
    )
    token.approve(contract.address, a * 2)
    contract.contribute()
    for addy in b:
        contract.add_payer(addy)
        with boa.env.prank(addy):
            token.approve(contract.address, a)
            contract.contribute()
    contract.execute_payment()
    print(contract.contribution(boa.env.eoa)[0])
    contract.refund_overpayment()
