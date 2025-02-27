-- comb_lock.vhdl
-- x1 styrs av vänster skjutomkopplare S1
-- x0 styrs av höger skjutomkopplare S0
-- Typically connect the following at the connector area of DigiMod
-- sclk <-- 32kHz

library ieee;
  use ieee.std_logic_1164.all;
  use IEEE.numeric_std.all;

entity comb_lock is
  port (clk   : in  std_logic; -- "fast enough"
        reset : in  std_logic; -- active high
        x1    : in  std_logic; -- x1 is left
        x0    : in  std_logic; -- x0 is right
        u     : out std_logic
       );
end entity;

architecture rtl of comb_lock is
  -- signals etc
  signal x_sync : std_logic_vector(1 downto 0);
  signal q, q_plus : std_logic_vector(1 downto 0);
  
  signal qx : std_logic_vector(3 downto 0);


  type rom is array (0 to 15) of std_logic_vector(1 downto 0);
  constant mem : rom := (
    "01", -- 0
    "00", -- 1
    "00", -- 2
    "00", -- 3
    "01", -- 4
    "10", -- 5
    "00", -- 6
    "00", -- 7
    "01", -- 8
    "10", -- 9
    "00", -- A
    "11", -- b
    "01", -- C
    "11", -- d
    "11", -- E
    "11" -- F
  );

begin
  process (clk)
  begin
    if reset = '1' then
      q <= (others => '0');
      x_sync <= (others => '0');
    elsif rising_edge(clk) then
      x_sync <= x1 & x0;
      q <= q_plus;
      end if;
  end process;

  qx <= q & x_sync;
  q_plus <= mem(to_integer(unsigned(qx)));

  u <= q(1) and q(0);

end architecture;
