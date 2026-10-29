library ieee;
use ieee.std_logic_1164.all;

entity game_controller is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        start_pulse  : in  std_logic;
        left_press   : in  std_logic;
        right_press  : in  std_logic;
        time_up      : in  std_logic;

        init_game    : out std_logic;
        playing      : out std_logic;
        state_code   : out std_logic_vector(1 downto 0)
    );
end entity game_controller;

architecture rtl of game_controller is

    type state_type is (READY, PLAYING_STATE, GAME_OVER);
    signal state : state_type := READY;

begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= READY;
            else
                case state is
                    when READY =>
                        if start_pulse = '1' then
                            state <= PLAYING_STATE;
                        end if;

                    when PLAYING_STATE =>
                        if time_up = '1' then
                            state <= GAME_OVER;
                        end if;

                    when GAME_OVER =>
                        if left_press = '1' then
                            state <= PLAYING_STATE;
                        elsif right_press = '1' then
                            state <= READY;
                        end if;
                end case;
            end if;
        end if;
    end process;

    init_game <= '1' when reset = '0' and
        ((state = READY and start_pulse = '1') or
         (state = GAME_OVER and left_press = '1'))
        else '0';

    playing <= '1' when state = PLAYING_STATE else '0';

    with state select
        state_code <=
            "00" when READY,
            "01" when PLAYING_STATE,
            "10" when GAME_OVER;

end architecture rtl;
