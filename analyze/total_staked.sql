-- 1）Total amount locked

--- 1. 所有活跃验证者金额（= 质押金额 + 未所有withdrawal）
select totalvalidatorbalance / 1e9
from epochs
where epoch = (select max(epoch) from epochs)

--- 2. 所有deposited和pending的锁仓金额（= 所有未激活，但已质押到合约的金额）
select sum(ed.amount) / 1e9
from eth1_deposits as ed
left join validators as v on encode(ed.publickey, 'hex') = v.pubkeyhex
where v.pubkeyhex is null -- 在validator中不存在
   or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活

--- 3. 最终: 组合在一起
select sum(amount)
from (select totalvalidatorbalance / 1e9 as amount
      from epochs
      where epoch = (select max(epoch) from epochs)
      union
      select sum(ed.amount) / 1e9
      from eth1_deposits as ed
               left join validators as v on encode(ed.publickey, 'hex') = v.pubkeyhex
      where v.pubkeyhex is null -- 在validator中不存在
         or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活
     ) as t