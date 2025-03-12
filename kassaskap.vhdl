library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity kassaskap is
  port (clk          : in  std_logic;                    -- "high" frequency
        reset        : in  std_logic;                    -- active high
        oppna_stang  : in  std_logic;                    -- 1=open, 0=close
        spara        : in  std_logic;                    -- active high
        oppen_stangd : out std_logic;                    -- 1=open, 0=closed
        ny_kod_ok    : out std_logic;
        rota, rotb   : in  std_logic;
        seg          : out std_logic_vector(6 downto 0); -- Segments
        dp           : out std_logic;                    -- Decimal point
        an           : out std_logic_vector(3 downto 0)  -- Digit to display
       );
end entity;

architecture rtl of kassaskap is
  signal oppna_stang_old, spara_old, oppna_stang_sync, spara_sync : std_logic;
  signal t_puls_oppna_stang, t_puls_spara : std_logic;
  signal rot_a_sync, rot_a_old, rot_b_sync, rot_b_old : std_logic;
  signal oppen_stangd_internal : std_logic := '1';
  signal ny_kod_ok_internal : std_logic;

  signal retry_flag : std_logic := '0';

  signal digit1 : unsigned(3 downto 0) := (others => '0'); -- Första sparade siffran
  signal digit2 : unsigned(3 downto 0) := (others => '0'); -- Andra sparade siffran
  signal combination : unsigned(7 downto 0) := (others => '0'); -- Kombination (00-99)

  signal answer_digit1 : unsigned(3 downto 0) := (others => '0'); -- Första sparade siffran
  signal answer_digit2 : unsigned(3 downto 0) := (others => '0'); -- Andra sparade siffran
  signal answer_combination : unsigned(7 downto 0) := (others => '0'); -- Kombination (00-99)

  
  signal state : integer range 0 to 3 := 0; -- 0 = välj första siffran, 1 = välj andra siffran, 2 = färdig

  signal count : unsigned(3 downto 0);


  
  -- OBS. För att testbänken ska fungera, så måste koden sättas till 00 vid reset.

  type rom is array (0 to 15) of std_logic_vector(6 downto 0); --prom som vi vet funkar för displayen.
  constant mem : rom := (
    "1000000", -- 0
    "1111001", -- 1
    "0100100", -- 2
    "0110000", -- 3
    "0011001", -- 4
    "0010010", -- 5
    "0000010", -- 6
    "1111000", -- 7
    "0000000", -- 8
    "0010000", -- 9
    "0001000", -- A
    "0000011", -- b
    "1000110", -- C
    "0100001", -- d
    "0000110", -- E
    "0001110" -- F
  );

begin
  process(clk, reset) begin -- synca insignaler och gör t_pulsare
    if reset = '1' then
      oppna_stang_old <= '0';
      oppna_stang_sync <= '0';
      spara_sync <= '0';
      spara_old <= '0';
      rot_a_sync <= '0';
      rot_a_old <= '0';
      rot_b_sync <= '0';
      rot_b_old <= '0';
    elsif rising_edge(clk) then
      oppna_stang_sync <= oppna_stang;
      oppna_stang_old <= oppna_stang_sync;

      spara_sync <= spara;
      spara_old <= spara_sync;

      rot_a_sync <= rota;
      rot_a_old <= rot_a_sync;
      rot_b_sync <= rotb;
      rot_b_old <= rot_b_sync;
    end if;
  end process;

  t_puls_oppna_stang <= oppna_stang_sync and (not oppna_stang_old);

  t_puls_spara <= spara_sync and (not spara_old);


  process(clk, reset) begin -- räknare
    if reset = '1' then
        count <= to_unsigned(0, 4); -- Nollställ räknaren
    elsif rising_edge(clk) then
        if rot_a_old = '0' and rot_a_sync = '1' and rot_b_sync = '0' then
            -- Om endast 'rota' är hög, öka räknaren
            if count = "1001" then
                count <= "0000"; -- Stanna vid 9
            else 
                count <= count + 1;
            end if;
        elsif rot_b_old = '0' and rot_b_sync = '1' and rot_a_sync = '0' then
            -- Om endast 'rotb' är hög, minska räknaren
            if count = "0000" then
                count <= "1001"; -- Stanna vid 0
            else 
                count <= count - 1;
            end if;
        end if;
    end if;
end process;

process(clk, reset)
begin
    if reset = '1' then
        digit1 <= (others => '0'); 
        digit2 <= (others => '0');
        answer_digit1 <= (others => '0');
        answer_digit2 <= (others => '0');
        answer_combination <= (others => '0');
        combination <= (others => '0');
        state <= 0;
        ny_kod_ok_internal <= '0';
        oppen_stangd_internal <= '1';
        retry_flag <= '0';
    elsif rising_edge(clk) then
        if t_puls_spara = '1' then
            case state is
                when 0 =>
                    digit1 <= count; -- Spara första siffran
                    state <= 1;

                when 1 =>
                    digit2 <= count; -- Spara andra siffran
                    combination <= digit1 * 10 + digit2;
                    if t_puls_oppna_stang = '0' then -- Bilda tvåsiffrig kombination
                      ny_kod_ok_internal <= '1';
                      oppen_stangd_internal <= '0'; -- Signalera att en kod har sparats
                      state <= 2;
                    end if;
                when 2 =>
                    answer_digit1 <= count;
                    state <= 3;

                when 3 =>
                    answer_digit2 <= count;
                    answer_combination <= answer_digit1 * 10 + answer_digit2; -- Bilda tvåsiffrig kod

                    -- **Flytta kodjämförelsen hit istället för öppningsprocessen**
                    if combination = answer_combination and t_puls_oppna_stang = '1' then
                        oppen_stangd_internal <= '1'; -- Rätt kod, öppna skåpet
                        ny_kod_ok_internal <= '0'; -- Koden är korrekt, sluta indikera
                        retry_flag <= '0';
                        state <= 0 ; -- Inget behov av att försöka igen
                    else
                        oppen_stangd_internal <= '0'; -- Fel kod, håll låst
                        retry_flag <= '1'; -- Försök igen
                    end if;

                when others =>
                    state <= 0;
            end case;
        end if;

        -- **Om retry_flag är satt, återgå till state 2**
        if retry_flag = '1' then
            state <= 2;
            retry_flag <= '0'; -- Återställ flaggan
        end if;
    end if;
end process;




seg <= mem(to_integer(count));
an <= "1110";
dp <= '1';
oppen_stangd <= oppen_stangd_internal;
ny_kod_ok <= ny_kod_ok_internal;

end architecture;
