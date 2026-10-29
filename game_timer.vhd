library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game_timer is
    generic (
        CLK_HZ       : positive := 50_000_000;
        GAME_SECONDS : positive := 60
    );
    port (
        clk               : in  std_logic;
        reset             : in  std_logic;
        init_game         : in  std_logic;
        playing           : in  std_logic;

        remaining_seconds : out unsigned(6 downto 0);
        time_up           : out std_logic
    );
end entity game_timer;

architecture rtl of game_timer is

    signal clock_count : integer range 0 to CLK_HZ - 1 := 0;
    signal seconds_reg : integer range 0 to GAME_SECONDS := GAME_SECONDS;

begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or init_game = '1' then
                clock_count <= 0;
                seconds_reg <= GAME_SECONDS;

            elsif playing = '1' and seconds_reg > 0 then
                if clock_count = CLK_HZ - 1 then
                    clock_count <= 0;
                    seconds_reg <= seconds_reg - 1;
                else
                    clock_count <= clock_count + 1;
                end if;
            end if;
        end if;
    end process;

    remaining_seconds <= to_unsigned(seconds_reg, 7);

    time_up <= '1' when playing = '1' and seconds_reg = 0
               else '0';

end architecture rtl;
