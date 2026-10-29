library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity input_manager is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;

        packet_valid    : in  std_logic;
        remote_position : in  unsigned(15 downto 0);
        remote_left     : in  std_logic;
        remote_right    : in  std_logic;

        frame_tick      : in  std_logic;

        left_held       : out std_logic;
        right_held      : out std_logic;

        start_pulse     : out std_logic;
        left_press      : out std_logic;
        right_press     : out std_logic;

        reel_delta      : out signed(15 downto 0);
        reel_valid      : out std_logic
    );
end entity input_manager;

architecture rtl of input_manager is

    signal latest_position   : unsigned(15 downto 0) := (others => '0');
    signal consumed_position : unsigned(15 downto 0) := (others => '0');

    signal position_ready : std_logic := '0';

    signal left_reg  : std_logic := '0';
    signal right_reg : std_logic := '0';

begin

    left_held  <= left_reg;
    right_held <= right_reg;

    process (clk)
        variable frame_difference : signed(15 downto 0);
    begin
        if rising_edge(clk) then

            start_pulse <= '0';
            left_press  <= '0';
            right_press <= '0';
            reel_valid  <= '0';

            if reset = '1' then
                latest_position   <= (others => '0');
                consumed_position <= (others => '0');
                position_ready    <= '0';

                left_reg    <= '0';
                right_reg   <= '0';
                reel_delta  <= (others => '0');

            else

                if packet_valid = '1' then
                    latest_position <= remote_position;

                    if position_ready = '0' then
                        consumed_position <= remote_position;
                        position_ready <= '1';
                    end if;

                    if remote_left = '1' and left_reg = '0' then
                        left_press  <= '1';
                        start_pulse <= '1';
                    end if;

                    if remote_right = '1' and right_reg = '0' then
                        right_press <= '1';
                        start_pulse <= '1';
                    end if;

                    left_reg  <= remote_left;
                    right_reg <= remote_right;
                end if;

                if frame_tick = '1' and position_ready = '1' then
                    frame_difference :=
                        signed(latest_position - consumed_position);

                    if to_integer(frame_difference) > 20 or
                       to_integer(frame_difference) < -20 then
                        reel_delta <= (others => '0');
                    else
                        reel_delta <= frame_difference;
                    end if;
                    consumed_position <= latest_position;
                    reel_valid <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
