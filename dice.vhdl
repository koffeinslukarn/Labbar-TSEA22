library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  -- klar labb 3

entity dice is
  port (
    clk   : in  std_logic;
    reset : in  std_logic;
    roll  : in  std_logic;
    fake  : in  std_logic;
    seg   : out std_logic_vector(6 downto 0);
    dp    : out std_logic;
    an    : out std_logic_vector(3 downto 0));
end entity;

architecture arch of dice is
  -- signals etc
  signal roll_sync  : std_logic;
  signal fake_sync  : std_logic;
  signal count      : integer range 1 to 8 := 1;
  signal result     : std_logic_vector(6 downto 0);

  -- 7-segment avkodning
  type rom is array (1 to 8) of std_logic_vector(6 downto 0);
  constant mem : rom := (
    "1111001", -- 1
    "0100100", -- 2
    "0110000", -- 3
    "0011001", -- 4
    "0010010", -- 5
    "0000010", -- 6 (riktig tärning)
    "0000010", -- 6 (falsk tärning)
    "0000010"  -- 6 (falsk tärning)
  );

begin

  -- Synkronisering av insignaler
  process (clk)
  begin
    if reset = '1' then
      roll_sync <= '0';
      fake_sync <= '0';
    elsif rising_edge(clk) then
      roll_sync <= roll;
      fake_sync <= fake;
    end if;
  end process;

  -- Räkneprocess för att simulera tärningen
  process (clk)
  begin
    if reset = '1' then
      count <= 1;
    elsif rising_edge(clk) then
      if roll_sync = '1' then
        if fake_sync = '1' then
          -- Falsk tärning: 6 ska ha 3x större sannolikhet
          if count = 8 then
            count <= 1;
          else
            count <= count + 1;
          end if;
        else
          -- Riktig tärning: 1 till 6 med lika sannolikhet
          if count = 6 then
            count <= 1;
          else
            count <= count + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Utsignaler
  result <= mem(count);
  seg <= result;
  dp  <= '1';  -- Ingen punkt
  an  <= "1110"; -- Aktivera första displayen

end architecture;