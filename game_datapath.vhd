LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY game_datapath IS
    PORT (
        clk, reset, init_game, playing : IN STD_LOGIC;
        left_held, right_held : IN STD_LOGIC;
        reel_delta : IN signed(15 DOWNTO 0);
        reel_valid : IN STD_LOGIC;
        hook_x, hook_y : OUT unsigned(9 DOWNTO 0);
        fish_x_bus, fish_y_bus : OUT STD_LOGIC_VECTOR(49 DOWNTO 0);
        fish_kind_bus : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        fish_dir_bus, fish_visible : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        held_active : OUT STD_LOGIC;
        held_kind : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        boot_x, boot_y, eel_x, eel_y : OUT unsigned(9 DOWNTO 0);
        stunned : OUT STD_LOGIC;
        score : OUT unsigned(9 DOWNTO 0)
    );
END ENTITY;

ARCHITECTURE rtl OF game_datapath IS
    CONSTANT SURFACE_Y : INTEGER := 80;
    CONSTANT BOTTOM_Y : INTEGER := 440;
    CONSTANT FISH_LEFT : INTEGER := 16;
    CONSTANT FISH_RIGHT : INTEGER := 596;
    CONSTANT STUN_CLOCKS : INTEGER := 250_000_000;

    TYPE x_array IS ARRAY (0 TO 4) OF INTEGER RANGE 0 TO 639;
    TYPE y_array IS ARRAY (0 TO 4) OF INTEGER RANGE 0 TO 479;
    TYPE kind_array IS ARRAY (0 TO 4) OF STD_LOGIC_VECTOR(1 DOWNTO 0);

    SIGNAL hook_x_reg : INTEGER RANGE 0 TO 639 := 320;
    SIGNAL hook_y_reg : INTEGER RANGE SURFACE_Y TO BOTTOM_Y := SURFACE_Y;
    SIGNAL fish_x_reg : x_array := (70, 170, 270, 370, 470);
    SIGNAL fish_y_reg : y_array := (150, 205, 260, 315, 370);
    SIGNAL fish_kind_reg : kind_array := ("00", "01", "10", "11", "00");
    SIGNAL fish_right_reg : STD_LOGIC_VECTOR(4 DOWNTO 0) := "10101";
    SIGNAL fish_visible_reg : STD_LOGIC_VECTOR(4 DOWNTO 0) := "11111";
    SIGNAL held_reg : STD_LOGIC := '0';

    SIGNAL held_slot_bits : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL held_kind_reg : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    SIGNAL score_reg : unsigned(9 DOWNTO 0) := (OTHERS => '0');

    SIGNAL boot_x_reg : INTEGER RANGE 0 TO 639 := 215;
    SIGNAL boot_y_reg : INTEGER RANGE 0 TO 479 := 400;
    SIGNAL boot_cooldown : INTEGER RANGE 0 TO 60 := 0;
    SIGNAL eel_x_reg : INTEGER RANGE 0 TO 639 := 505;
    SIGNAL eel_y_reg : INTEGER RANGE 0 TO 479 := 330;
    SIGNAL eel_right_reg : STD_LOGIC := '0';
    SIGNAL stun_count : INTEGER RANGE 0 TO STUN_CLOCKS := 0;
    SIGNAL rng_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"ACE1";

    FUNCTION choose_fish(r : unsigned(15 DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
    BEGIN

        IF r <= to_unsigned(1966, 16) THEN
            RETURN "11";
        ELSIF r <= to_unsigned(24215, 16) THEN
            RETURN "00";
        ELSIF r <= to_unsigned(49643, 16) THEN
            RETURN "01";
        ELSE
            RETURN "10";
        END IF;
    END FUNCTION;

    FUNCTION fish_points(k : STD_LOGIC_VECTOR(1 DOWNTO 0))
        RETURN INTEGER IS
    BEGIN
        CASE k IS
            WHEN "00" => RETURN 1;
            WHEN "01" => RETURN 5;
            WHEN "10" => RETURN 10;
            WHEN OTHERS => RETURN 20;
        END CASE;
    END FUNCTION;

    FUNCTION fish_speed(k : STD_LOGIC_VECTOR(1 DOWNTO 0))
        RETURN INTEGER IS
    BEGIN
        CASE k IS
            WHEN "00" => RETURN 1;
            WHEN "01" => RETURN 2;
            WHEN "10" => RETURN 4;
            WHEN OTHERS => RETURN 3;
        END CASE;
    END FUNCTION;
BEGIN

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                rng_reg <= x"ACE1";
            ELSE
                rng_reg <= (rng_reg(0) XOR rng_reg(2) XOR
                    rng_reg(3) XOR rng_reg(5)) & rng_reg(15 DOWNTO 1);
            END IF;
        END IF;
    END PROCESS;

    PROCESS (clk)
        VARIABLE nx, ny : INTEGER;
        VARIABLE ex : INTEGER;
        VARIABLE swim_x : x_array;
        VARIABLE points : INTEGER;
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' OR init_game = '1' THEN
                hook_x_reg <= 320;
                hook_y_reg <= SURFACE_Y;
                fish_x_reg <= (70, 170, 270, 370, 470);
                fish_y_reg <= (150, 205, 260, 315, 370);
                fish_right_reg <= "10101";
                fish_visible_reg <= "11111";
                held_reg <= '0';
                held_slot_bits <= (OTHERS => '0');
                held_kind_reg <= "00";
                score_reg <= (OTHERS => '0');
                boot_x_reg <= 215;
                boot_y_reg <= 400;
                boot_cooldown <= 0;
                eel_x_reg <= 505;
                eel_y_reg <= 330;
                eel_right_reg <= '0';
                stun_count <= 0;
                IF reset = '1' THEN
                    fish_kind_reg <= ("00", "01", "10", "11", "00");
                ELSE

                    fish_kind_reg(0) <= "00";
                    fish_kind_reg(1) <= "01";
                    fish_kind_reg(2) <= "10";
                    fish_kind_reg(3) <= "11";
                    fish_kind_reg(4) <= choose_fish(unsigned(rng_reg));
                END IF;

            ELSIF playing = '1' THEN
                IF stun_count > 0 THEN
                    stun_count <= stun_count - 1;
                END IF;

                IF reel_valid = '1' THEN
                    IF boot_cooldown > 0 THEN
                        boot_cooldown <= boot_cooldown - 1;
                    END IF;

                    FOR i IN 0 TO 4 LOOP
                        swim_x(i) := fish_x_reg(i);
                        IF fish_visible_reg(i) = '1' THEN
                            IF fish_right_reg(i) = '1' THEN
                                IF fish_x_reg(i) + fish_speed(fish_kind_reg(i))
                                    >= FISH_RIGHT THEN
                                    swim_x(i) := FISH_RIGHT;
                                    fish_right_reg(i) <= '0';
                                ELSE
                                    swim_x(i) := fish_x_reg(i) +
                                    fish_speed(fish_kind_reg(i));
                                END IF;
                            ELSE
                                IF fish_x_reg(i) - fish_speed(fish_kind_reg(i))
                                    <= FISH_LEFT THEN
                                    swim_x(i) := FISH_LEFT;
                                    fish_right_reg(i) <= '1';
                                ELSE
                                    swim_x(i) := fish_x_reg(i) -
                                    fish_speed(fish_kind_reg(i));
                                END IF;
                            END IF;
                            fish_x_reg(i) <= swim_x(i);
                        END IF;
                    END LOOP;

                    ex := eel_x_reg;
                    IF eel_right_reg = '1' THEN
                        IF ex >= 585 THEN
                            eel_right_reg <= '0';
                        ELSE
                            eel_x_reg <= ex + 2;
                        END IF;
                    ELSE
                        IF ex <= 24 THEN
                            eel_right_reg <= '1';
                        ELSE
                            eel_x_reg <= ex - 2;
                        END IF;
                    END IF;

                    IF stun_count = 0 THEN
                        nx := hook_x_reg;
                        ny := hook_y_reg - to_integer(reel_delta) * 3;
                        IF left_held = '1' AND right_held = '0' THEN
                            nx := nx - 3;
                        ELSIF right_held = '1' AND left_held = '0' THEN
                            nx := nx + 3;
                        END IF;
                        IF nx < 0 THEN
                            nx := 0;
                        ELSIF nx > 639 THEN
                            nx := 639;
                        END IF;
                        IF ny < SURFACE_Y THEN
                            ny := SURFACE_Y;
                        ELSIF ny > BOTTOM_Y THEN
                            ny := BOTTOM_Y;
                        END IF;
                        hook_x_reg <= nx;
                        hook_y_reg <= ny;

                        IF held_reg = '1' AND ny = SURFACE_Y THEN
                            points := fish_points(held_kind_reg);
                            IF to_integer(score_reg) + points > 999 THEN
                                score_reg <= to_unsigned(999, 10);
                            ELSE
                                score_reg <= score_reg +
                                    to_unsigned(points, 10);
                            END IF;
                            held_reg <= '0';
                            held_slot_bits <= (OTHERS => '0');
                            FOR i IN 0 TO 4 LOOP
                                IF held_slot_bits(i) = '1' THEN
                                    fish_visible_reg(i) <= '1';
                                    fish_kind_reg(i) <= choose_fish(
                                    unsigned(rng_reg) XOR
                                    to_unsigned(15317 * i, 16));
                                    fish_x_reg(i) <= 50 + i * 105 +
                                    to_integer(unsigned(rng_reg(9 DOWNTO 8))) * 28;
                                    fish_y_reg(i) <= 145 + i * 55 +
                                    to_integer(unsigned(rng_reg(3 DOWNTO 2))) * 5;
                                    fish_right_reg(i) <= rng_reg(10);
                                END IF;
                            END LOOP;

                        ELSIF boot_cooldown = 0 AND
                            nx >= boot_x_reg AND nx < boot_x_reg + 26 AND
                            ny >= boot_y_reg AND ny < boot_y_reg + 22 THEN
                            IF to_integer(score_reg) < 5 THEN
                                score_reg <= (OTHERS => '0');
                            ELSE
                                score_reg <= score_reg - to_unsigned(5, 10);
                            END IF;
                            boot_cooldown <= 60;
                            IF nx < 320 THEN
                                boot_x_reg <= 460;
                            ELSE
                                boot_x_reg <= 125;
                            END IF;
                            IF boot_y_reg = 400 THEN
                                boot_y_reg <= 385;
                            ELSE
                                boot_y_reg <= 400;
                            END IF;

                        ELSIF nx >= ex AND nx < ex + 36 AND
                            ny >= eel_y_reg AND ny < eel_y_reg + 16 THEN
                            stun_count <= STUN_CLOCKS - 1;
                            IF nx < 320 THEN
                                eel_x_reg <= 505;
                            ELSE
                                eel_x_reg <= 75;
                            END IF;
                            IF eel_y_reg = 330 THEN
                                eel_y_reg <= 245;
                            ELSE
                                eel_y_reg <= 330;
                            END IF;

                        ELSIF held_reg = '0' THEN

                            FOR i IN 0 TO 4 LOOP
                                IF fish_visible_reg(i) = '1' AND
                                    nx >= swim_x(i) AND nx < swim_x(i) + 28 AND
                                    ny >= fish_y_reg(i) AND
                                    ny < fish_y_reg(i) + 16 THEN
                                    held_reg <= '1';
                                    held_slot_bits(i) <= '1';
                                    held_kind_reg <= fish_kind_reg(i);
                                    fish_visible_reg(i) <= '0';
                                END IF;
                            END LOOP;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    gen_fish_bus : FOR i IN 0 TO 4 GENERATE
        fish_x_bus(i * 10 + 9 DOWNTO i * 10) <=
        STD_LOGIC_VECTOR(to_unsigned(fish_x_reg(i), 10));
        fish_y_bus(i * 10 + 9 DOWNTO i * 10) <=
        STD_LOGIC_VECTOR(to_unsigned(fish_y_reg(i), 10));
        fish_kind_bus(i * 2 + 1 DOWNTO i * 2) <= fish_kind_reg(i);
    END GENERATE;

    hook_x <= to_unsigned(hook_x_reg, 10);
    hook_y <= to_unsigned(hook_y_reg, 10);
    fish_dir_bus <= fish_right_reg;
    fish_visible <= fish_visible_reg;
    held_active <= held_reg;
    held_kind <= held_kind_reg;
    boot_x <= to_unsigned(boot_x_reg, 10);
    boot_y <= to_unsigned(boot_y_reg, 10);
    eel_x <= to_unsigned(eel_x_reg, 10);
    eel_y <= to_unsigned(eel_y_reg, 10);
    stunned <= '1' WHEN stun_count /= 0 ELSE
        '0';
    score <= score_reg;
END ARCHITECTURE;
