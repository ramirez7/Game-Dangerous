-- Game :: Dangerous code by Steven Tinsley.  You are free to use this software and view its source code.
-- If you wish to redistribute it or use it as part of your own work, this is permitted as long as you acknowledge the work is by the abovementioned author.

module Main where

import System.IO
import Foreign
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal.Utils
import Graphics.GL.Core33
import Graphics.UI.GLUT
import Data.Bits
import Data.Word
import Data.List.Split
import Data.Matrix hiding ((!))
import qualified Data.Sequence as SEQ
import Data.IORef
import System.Environment
import Data.Coerce
import Unsafe.Coerce
import Data.Array.IArray
import Data.Array.Unboxed
import Control.Concurrent
import qualified Data.ByteString as BS
import Control.Exception
import System.Exit
import System.Random
import Build_model
import Game_logic
import Decompress_map
import Game_sound

main = do
  args <- getArgs
  contents <- bracket (openFile (args !! 0) ReadMode) (hClose) (\h -> do contents <- hGetContents h; putStr ("\nconfig file size: " ++ show (length contents)); return contents)
  if length args > 3 then open_window ((listArray (0, 51) (splitOneOf "=\n" contents)) // [(1, args !! 1), (9, args !! 2), (11, args !! 3), (13, args !! 4), (15, args !! 5), (17, args !! 6), (19, args !! 7), (21, args !! 8), (23, args !! 9), (25, args !! 10), (27, args !! 11), (29, args !! 12), (31, args !! 13), (33, args !! 14), (35, args !! 15), (39, "n")])
  else open_window ((listArray (0, 51) (splitOneOf "=\n" contents)) // [(31, args !! 1), (33, args !! 2)])

-- This function initialises the GLUT runtime system, which in turn is used to initialise a window and OpenGL context.
open_window :: Array Int [Char] -> IO ()
open_window conf_reg =
  let cfg' = cfg conf_reg 0
  in do
  putStr ("\nGame :: Dangerous engine " ++ cfg' "version_and_platform_string")
  putStr "\nInitialising GLUT and OpenGL runtime environment."
  initialize "game_dangerous.exe" []
  initialWindowSize $= (Size (cfg' "resolution_x") (cfg' "resolution_y"))
  initialDisplayMode $= [RGBAMode, WithAlphaComponent, WithDepthBuffer, DoubleBuffered]
  createWindow "Game :: Dangerous"
  actionOnWindowClose $= Exit
  displayCallback $= repaint_window
  keyboardCallback $= get_input
  contents <- bracket (openFile (cfg' "map_file") ReadMode) (hClose) (\h -> do contents <- hGetContents h; putStr ("\nmap file size: " ++ show (length contents)); return contents)
  setup_game hwnd hdc contents conf_reg

-- This is the callback that GLUT calls when it detects a window repaint is necessary.  This should only happen when the window is first opened, the user moves or resizes the window, or it is
-- overlapped by another window.  For standard frame rendering, show_frame and run_menu repaint the rendered area of the window.
repaint_window :: IO ()
repaint_window = do
  swapBuffers

-- This is the callback that GLUT calls each time mainLoopEvent has been called and there is keyboard input in the window message queue.
get_input :: IORef Int -> Array Int Char -> Char -> Position -> IO ()
get_input ref key_set key pos = do
  if key == key_set ! 0 then writeIORef ref 2
  else if key == key_set ! 1 then writeIORef ref 3
  else if key == key_set ! 2 then writeIORef ref 4
  else if key == key_set ! 3 then writeIORef ref 5
  else if key == key_set ! 4 then writeIORef ref 6
  else if key == key_set ! 5 then writeIORef ref 7
  else if key == key_set ! 6 then writeIORef ref 8
  else if key == key_set ! 7 then writeIORef ref 9
  else if key == key_set ! 8 then writeIORef ref 10
  else if key == key_set ! 9 then writeIORef ref 11
  else if key == key_set ! 10 then writeIORef ref 12
  else if key == key_set ! 11 then writeIORef ref 13
  else writeIORef ref 0

-- This function initialises the OpenGL and OpenAL contexts.  It also decompresses the map file, manages the compilation of GLSL shaders, loading of 3D models, loading of the light map
-- and loading of sound effects.
setup_game :: HWND -> HDC -> [Char] -> Array Int [Char] -> IO ()
setup_game hwnd hdc comp_env_map conf_reg =
  let m0 = "mod_to_world"
      m1 = "world_to_clip"
      m2 = "world_to_mod"
      lm0 = "lmap_pos0"
      lm1 = "lmap_pos1"
      lm2 = "lmap_int0"
      lm3 = "lmap_int1"
      lm4 = "lmap_t0"
      lm5 = "lmap_t1"
      proc_map' = proc_map (splitOn "\n~\n" comp_env_map) (read ((splitOn "\n~\n" comp_env_map) !! 12)) (read ((splitOn "\n~\n" comp_env_map) !! 13)) (read ((splitOn "\n~\n" comp_env_map) !! 14))
      env_map = ".~.~.~.~" ++ fst (proc_map') ++ "~" ++ snd (proc_map') ++ ((splitOn "\n~\n" comp_env_map) !! 10) ++ "~" ++ ((splitOn "\n~\n" comp_env_map) !! 11) ++ "~" ++ ((splitOn "\n~\n" comp_env_map) !! 12) ++ "~" ++ ((splitOn "\n~\n" comp_env_map) !! 13) ++ "~" ++ ((splitOn "\n~\n" comp_env_map) !! 14)
      cfg' = cfg conf_reg 0
      p_bind_limit = (read ((splitOn "\n~\n" comp_env_map) !! 7)) - 1
  in do
  pfd <- setPFD (40, 1, pfd_DRAW_TO_WINDOW .|. pfd_SUPPORT_OPENGL .|. pfd_DOUBLEBUFFER, pfd_TYPE_RGBA, 24, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, pfd_MAIN_PLANE, 0, 0, 0, 0)
  f_index <- choosePixelFormat hdc pfd
  setPixelFormat hdc f_index pfd
  putStr "\nInitialising OpenGL context..."
  hrc <- wglCreateContext hdc
  wglMakeCurrent hdc hrc
  glEnable GL_DEPTH_TEST
  glDepthFunc GL_LEQUAL
  glDepthRange 0 1
  glEnable GL_DEPTH_CLAMP
  contents0 <- bracket (openFile (cfg' "shader_file") ReadMode) (hClose) (\h -> do contents <- hGetContents h; putStr ("\nshader file size: " ++ show (length contents)); return contents)
  p_gl_program <- mallocBytes (7 * gluint)
  make_gl_program (tail (splitOn "#" contents0)) p_gl_program 0
  uniform <- find_gl_uniform [m0, m1, m2, lm0, lm1, lm2, lm3, lm4, lm5, "t", "mode", m0, m1, m2, lm0, lm1, lm2, lm3, lm4, lm5, "t", "mode", "tex_unit0", m0, m1, m2, "worldTorchPos", "timer", "mode", m0, m1, m2, "worldTorchPos", "timer", "mode", "tex_unit0", "tt_matrix", "tex_unit0", "mode", m0, m1, m2, "normal_transf", lm0, lm1, lm2, lm3, lm4, lm5, "tex_unit0", "t", m0, m1, "tex_unit0"] [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6] p_gl_program []
  gl_program0 <- peekElemOff p_gl_program 0; gl_program1 <- peekElemOff p_gl_program 1; gl_program2 <- peekElemOff p_gl_program 2; gl_program3 <- peekElemOff p_gl_program 3; gl_program4 <- peekElemOff p_gl_program 4; gl_program5 <- peekElemOff p_gl_program 5; gl_program6 <- peekElemOff p_gl_program 6
  glClearColor 0 0 0 0
  glClearDepth 1
  contents1 <- bracket (openFile ((cfg' "model_data_dir") ++ ((splitOn "\n~\n" comp_env_map) !! 9)) ReadMode) (hClose) (\h -> do contents <- hGetContents h; putStr ("\nlight map file size: " ++ show (length contents)); return contents)
  p_lmap_pos0 <- callocBytes (glfloat * 300)
  p_lmap_pos1 <- callocBytes (glfloat * 300)
  p_lmap_int0 <- callocBytes (glfloat * 300)
  p_lmap_int1 <- callocBytes (glfloat * 300)
  p_lmap_t0 <- callocBytes (glfloat * 240)
  p_lmap_t1 <- callocBytes (glfloat * 240)
  load_array (take 300 (proc_floats (splitOn ", " ((splitOn "\n~\n" contents1) !! 0)))) p_lmap_pos0 0
  load_array (take 300 (proc_floats (splitOn ", " ((splitOn "\n~\n" contents1) !! 1)))) p_lmap_pos1 0
  load_array (take 300 (proc_floats (splitOn ", " ((splitOn "\n~\n" contents1) !! 2)))) p_lmap_int0 0
  load_array (take 300 (proc_floats (splitOn ", " ((splitOn "\n~\n" contents1) !! 3)))) p_lmap_int1 0
  load_array (take 240 (proc_floats (splitOn ", " ((splitOn "\n~\n" contents1) !! 4)))) p_lmap_t0 0
  load_array (take 240 (proc_floats (splitOn ", " ((splitOn "\n~\n" contents1) !! 5)))) p_lmap_t1 0
  glUseProgram gl_program0
  glUniform3fv (fromIntegral (uniform !! 3)) 100 (castPtr p_lmap_pos0)
  glUniform3fv (fromIntegral (uniform !! 4)) 100 (castPtr p_lmap_pos1)
  glUniform3fv (fromIntegral (uniform !! 5)) 100 (castPtr p_lmap_int0)
  glUniform3fv (fromIntegral (uniform !! 6)) 100 (castPtr p_lmap_int1)
  glUniform1fv (fromIntegral (uniform !! 7)) 240 (castPtr p_lmap_t0)
  glUniform1fv (fromIntegral (uniform !! 8)) 240 (castPtr p_lmap_t1)
  glUseProgram gl_program1
  glUniform1i (fromIntegral (uniform !! 22)) 0
  glUniform3fv (fromIntegral (uniform !! 14)) 100 (castPtr p_lmap_pos0)
  glUniform3fv (fromIntegral (uniform !! 15)) 100 (castPtr p_lmap_pos1)
  glUniform3fv (fromIntegral (uniform !! 16)) 100 (castPtr p_lmap_int0)
  glUniform3fv (fromIntegral (uniform !! 17)) 100 (castPtr p_lmap_int1)
  glUniform1fv (fromIntegral (uniform !! 18)) 240 (castPtr p_lmap_t0)
  glUniform1fv (fromIntegral (uniform !! 19)) 240 (castPtr p_lmap_t1)
  glUseProgram gl_program3
  glUniform1i (fromIntegral (uniform !! 35)) 0
  glUseProgram gl_program4
  glUniform1i (fromIntegral (uniform !! 37)) 0
  glUseProgram gl_program5
  glUniform1i (fromIntegral (uniform !! 49)) 0
  glUniform3fv (fromIntegral (uniform !! 43)) 100 (castPtr p_lmap_pos0)
  glUniform3fv (fromIntegral (uniform !! 44)) 100 (castPtr p_lmap_pos1)
  glUniform3fv (fromIntegral (uniform !! 45)) 100 (castPtr p_lmap_int0)
  glUniform3fv (fromIntegral (uniform !! 46)) 100 (castPtr p_lmap_int1)
  glUniform1fv (fromIntegral (uniform !! 47)) 240 (castPtr p_lmap_t0)
  glUniform1fv (fromIntegral (uniform !! 48)) 240 (castPtr p_lmap_t1)
  glUseProgram gl_program6
  glUniform1i (fromIntegral (uniform !! 53)) 0
  putStr "\nCompiling OpenGL shader programs..."
  validate_prog gl_program0 0
  validate_prog gl_program1 1
  validate_prog gl_program2 2
  validate_prog gl_program3 3
  validate_prog gl_program4 4
  validate_prog gl_program5 5
  validate_prog gl_program6 6
  p_bind <- buffer_to_array (castPtr p_gl_program) (array (0, p_bind_limit) [(x, 0) | x <- [0..p_bind_limit]]) 0 (p_bind_limit - 6) 6
  putStr "\nLoading 3D models..."
  mod_bind <- callocBytes ((read ((splitOn "\n~\n" comp_env_map) !! 7)) * gluint)
  load_mod_file (init (splitOn ", " ((splitOn "\n~\n" comp_env_map) !! 8))) (cfg' "model_data_dir") mod_bind
  free p_gl_program; free p_lmap_pos0; free p_lmap_pos1; free p_lmap_int0; free p_lmap_int1; free p_lmap_t0; free p_lmap_t1
  p_bind_ <- buffer_to_array (castPtr mod_bind) p_bind 0 0 (p_bind_limit - 16)
  init_al_context
  contents2 <- bracket (openFile ((cfg' "sound_data_dir") ++ (last (splitOn ", " ((splitOn "\n~\n" comp_env_map) !! 8)))) ReadMode) (hClose) (\h -> do contents <- hGetContents h; putStr ("\nsound map size: " ++ show (length contents)); return contents)
  sound_array <- init_al_effect0 (splitOneOf "\n " contents2) (cfg' "sound_data_dir") (array (0, 255) [(x, Source 0) | x <- [0..255]])
  start_game hwnd hdc (listArray (0, 52) uniform) (p_bind_, p_bind_limit + 1) env_map conf_reg (-1) (read (cfg' "init_u"), read (cfg' "init_v"), read (cfg' "init_w"), read (cfg' "gravity"), read (cfg' "friction"), read (cfg' "run_power"), read (cfg' "jump_power")) def_save_state sound_array

-- The model file(s) that describe all 3D and 2D models referenced in the current map are loaded here.
load_mod_file :: [[Char]] -> [Char] -> Ptr GLuint -> IO ()
load_mod_file [] path p_bind = return ()
load_mod_file (x:xs) path p_bind = do
  h <- openFile (path ++ x) ReadMode
  mod_data <- hGetContents h
  if ((splitOn "~" mod_data) !! 0) == [] then setup_object (load_object0 (splitOn "&" ((splitOn "~" mod_data) !! 1))) (proc_marker (proc_ints (splitOn ", " ((splitOn "~" mod_data) !! 2)))) (proc_floats (splitOn ", " ((splitOn "~" mod_data) !! 3))) (proc_elements (splitOn ", " ((splitOn "~" mod_data) !! 4))) [] p_bind
  else do
    bs_tex <- load_bitmap0 (splitOn ", " ((splitOn "~" mod_data) !! 0)) (load_object0 (splitOn "&" ((splitOn "~" mod_data) !! 1))) path [] 1
    setup_object (load_object0 (splitOn "&" ((splitOn "~" mod_data) !! 1))) (proc_marker (proc_ints (splitOn ", " ((splitOn "~" mod_data) !! 2)))) (proc_floats (splitOn ", " ((splitOn "~" mod_data) !! 3))) (proc_elements (splitOn ", " ((splitOn "~" mod_data) !! 4))) bs_tex p_bind
  hClose h
  load_mod_file xs path p_bind

-- Functions used by start_game as part of game initialisation.
select_mode "y" = True
select_mode "n" = False

proc_splash :: [Char] -> Int -> [(Int, [Int])]
proc_splash [] c = []
proc_splash text 0 = (0, []) : proc_splash text 1
proc_splash text c = (c, conv_msg_ (take 48 text)) : proc_splash (drop 48 text) (c + 1)

gen_prob_seq :: RandomGen g => Int -> Int -> Int -> g -> UArray Int Int
gen_prob_seq i0 i1 i2 g = listArray (i0, i1) (drop i2 (randomRs (0, 99) g))

-- This function initialises the game logic and rendering threads each time a new game is started and handles user input from the main menu.
start_game :: HWND -> HDC -> UArray Int Int32 -> (UArray Int Word32, Int) -> [Char] -> Array Int [Char] -> Int -> (Float, Float, Float, Float, Float, Float, Float) -> Save_state -> Array Int Source -> IO ()
start_game hwnd hdc uniform p_bind c conf_reg mode (u, v, w, g, f, mag_r, mag_j) save_state sound_array =
  let u_limit = (read ((splitOn "~" c) !! 8))
      v_limit = (read ((splitOn "~" c) !! 9))
      w_limit = (read ((splitOn "~" c) !! 10))
      w_grid = check_map_layer (-3) 0 0 u_limit v_limit (make_array0 ((build_table0 (elems (build_table1 (splitOn ", " ((splitOn "~" c) !! 7)) (empty_w_grid u_limit v_limit w_limit) 7500)) u_limit v_limit w_limit) ++ (sort_grid0 (splitOn "&" ((splitOn "~" c) !! 4)))) u_limit v_limit w_limit) w_grid_flag
      f_grid = check_map_layer 0 0 0 ((div (u_limit + 1) 2) - 1) ((div (v_limit + 1) 2) - 1) (make_array1 (load_floor0 (splitOn "&" ((splitOn "~" c) !! 5))) ((div (u_limit + 1) 2) - 1) ((div (v_limit + 1) 2) - 1) w_limit) f_grid_flag
      obj_grid = check_map_layer 0 0 0 u_limit v_limit (empty_obj_grid u_limit v_limit w_limit // load_obj_grid (splitOn ", " ((splitOn "~" c) !! 6))) obj_grid_flag
      look_up_ = look_up [make_table 0 0, make_table 1 0, make_table 2 0, make_table 3 0]
      camera_to_clip' = fromList 4 4 [read (cfg' "frustumScale"), 0, 0, 0, 0, read (cfg' "frustumScale"), 0, 0, 0, 0, ((zFar + zNear) / (zNear - zFar)), ((2 * zFar * zNear) / (zNear - zFar)), 0, 0, -1, 0]
      cfg' = cfg conf_reg 0
  in do
  if mode == -1 then do
    if cfg' "splash" == "y" then do
      run_menu (proc_splash (cfg' "splash_msg") 0) [] (Io_box {hwnd_ = hwnd, hdc_ = hdc, uniform_ = uniform, p_bind_ = p_bind}) (-0.96) (-0.2) 0 0 0
      start_game hwnd hdc uniform p_bind c conf_reg 2 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
    else start_game hwnd hdc uniform p_bind c conf_reg 0 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
  else if mode == 0 || mode == 1 then do
    p_mt_matrix <- mallocBytes (glfloat * 128)
    p_f_table0 <- callocBytes (int_ * 120000)
    p_f_table1 <- callocBytes (int_ * 37500)
    state_ref <- newEmptyMVar
    t_log <- newEmptyMVar
    r_gen <- getStdGen
    if mode == 0 then do
      tid <- forkIO (update_play (Io_box {hwnd_ = hwnd, hdc_ = hdc, uniform_ = uniform, p_bind_ = p_bind}) state_ref (ps0_init {pos_u = u, pos_v = v, pos_w = w, show_fps_ = select_mode (cfg' "show_fps"), prob_seq = gen_prob_seq 0 239 (read (cfg' "prob_c")) r_gen}) (ps1_init {verbose_mode = select_mode (cfg' "verbose_mode")}) False (read (cfg' "min_frame_t")) (g, f, mag_r, mag_j) w_grid f_grid obj_grid look_up_ save_state sound_array 0 t_log (SEQ.empty) 60)
      result <- show_frame hdc p_bind uniform p_mt_matrix (p_f_table0, p_f_table1) 0 0 0 0 0 state_ref w_grid f_grid obj_grid look_up_ camera_to_clip' (array (0, 5) [(i, (0, [])) | i <- [0..5]])
      free p_mt_matrix
      free p_f_table0
      free p_f_table1
      killThread tid
      start_game hwnd hdc uniform p_bind c conf_reg ((head (fst result)) + 1) (u, v, w, g, f, mag_r, mag_j) (snd result) sound_array
    else do
      tid <- forkIO (update_play (Io_box {hwnd_ = hwnd, hdc_ = hdc, uniform_ = uniform, p_bind_ = p_bind}) state_ref (s0_ save_state) (s1_ save_state) False (read (cfg' "min_frame_t")) (g, f, mag_r, mag_j) (w_grid_ save_state) (f_grid_ save_state) (obj_grid_ save_state) look_up_ save_state sound_array 0 t_log (SEQ.empty) 60)
      result <- show_frame hdc p_bind uniform p_mt_matrix (p_f_table0, p_f_table1) 0 0 0 0 0 state_ref w_grid f_grid obj_grid look_up_ camera_to_clip' (array (0, 5) [(i, (0, [])) | i <- [0..5]])
      free p_mt_matrix
      free p_f_table0
      free p_f_table1
      killThread tid
      start_game hwnd hdc uniform p_bind c conf_reg ((head (fst result)) + 1) (u, v, w, g, f, mag_r, mag_j) (snd result) sound_array
  else if mode == 2 then do
    choice <- run_menu main_menu_text [] (Io_box {hwnd_ = hwnd, hdc_ = hdc, uniform_ = uniform, p_bind_ = p_bind}) (-0.75) (-0.75) 1 0 0
    if choice == 1 then start_game hwnd hdc uniform p_bind c conf_reg 0 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
    else if choice == 2 then do
      if is_set save_state == True then start_game hwnd hdc uniform p_bind c conf_reg 1 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
      else start_game hwnd hdc uniform p_bind c conf_reg 0 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
    else exitSuccess
  else if mode == 3 then do
    if is_set save_state == True then start_game hwnd hdc uniform p_bind c conf_reg 1 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
    else start_game hwnd hdc uniform p_bind c conf_reg 0 (u, v, w, g, f, mag_r, mag_j) save_state sound_array
  else if mode == 4 then exitSuccess
  else if mode == 6 then do
    putStr "\nYou have completed the demo.  Nice one.  Check the project website later for details of further releases."
    exitSuccess
  else return ()

-- Find the uniform locations of GLSL uniform variables.
find_gl_uniform :: [[Char]] -> [Int] -> Ptr GLuint -> [Int32] -> IO [Int32]
find_gl_uniform [] [] p_gl_program acc = return acc
find_gl_uniform (x:xs) (y:ys) p_gl_program acc = do
  query <- newCString x
  gl_program <- peekElemOff p_gl_program y
  uniform <- glGetUniformLocation gl_program query
  free query
  find_gl_uniform xs ys p_gl_program (acc ++ [fromIntegral uniform])

-- These four functions deal with the compilation of the GLSL shaders and linking of the shader program.
make_gl_program :: [[Char]] -> Ptr GLuint -> Int -> IO ()
make_gl_program [] p_prog i = return ()
make_gl_program (x0:x1:xs) p_prog i = do
  sc0 <- shader_code ["#" ++ x0] nullPtr 0
  sc1 <- shader_code ["#" ++ x1] nullPtr 0
  shader0 <- make_shader GL_VERTEX_SHADER sc0
  shader1 <- make_shader GL_FRAGMENT_SHADER sc1
  gl_program <- make_program [shader0, shader1] 0 0
  pokeElemOff p_prog i gl_program
  free sc0; free sc1
  make_gl_program xs p_prog (i + 1)

shader_code :: [[Char]] -> Ptr (Ptr GLchar) -> Int -> IO (Ptr (Ptr GLchar))
shader_code sources ptr 0 = do
  p0 <- mallocBytes (ptr_size * length sources)
  shader_code sources p0 1
shader_code [] ptr c = return ptr
shader_code (x:xs) ptr c = do
  p <- newCString x
  pokeByteOff ptr (ptr_size * (c - 1)) p
  shader_code xs ptr (c + 1)

make_shader :: GLenum -> Ptr (Ptr GLchar) -> IO GLuint
make_shader t_shader source = do
  shader <- glCreateShader t_shader
  glShaderSource shader 1 source nullPtr
  glCompileShader shader
  p0 <- mallocBytes (sizeOf glint)
  p1 <- mallocBytes (sizeOf glint)
  glGetShaderiv shader GL_COMPILE_STATUS p0
  status <- peek p0
  if status == 0 then do
    glGetShaderiv shader GL_INFO_LOG_LENGTH p1
    p2 <- mallocBytes 1024
    glGetShaderInfoLog shader 1024 nullPtr p2
    e <- peekCString p2
    putStr "\nGL shader compile error: "
    print e
    return shader
  else return shader

make_program :: [GLuint] -> GLuint -> Int -> IO GLuint
make_program shaders program 0 = do
  prog <- glCreateProgram
  make_program shaders prog 1
make_program [] program c = do
  glLinkProgram program
  return program
make_program (x:xs) program c = do
  glAttachShader program x
  make_program xs program c

-- Check for errors during GLSL program compilation.
validate_prog :: GLuint -> Int -> IO ()
validate_prog program n = do
  glValidateProgram program
  p0 <- mallocBytes (sizeOf glint)
  glGetProgramiv program GL_VALIDATE_STATUS p0
  e0 <- peek p0
  p1 <- mallocBytes 1024
  glGetProgramInfoLog program 1024 nullPtr p1
  e1 <- peekCString p1
  putStr ("\nValidating GLSL program " ++ show n ++ "...")
  putStr ("\ngl_program validate status: " ++ show e0)
  putStr "GL program info log: "
  print e1
  free p0; free p1

-- These functions load bitmap images used for textures.
set_pad :: Int -> Int
set_pad tex_w =
  if mod tex_w 4 == 0 then 0
  else 4 - mod tex_w 4

load_bitmap0 :: [[Char]] -> [Object] -> [Char] -> [BS.ByteString] -> Int -> IO [BS.ByteString]
load_bitmap0 [] _ path acc c = return acc
load_bitmap0 (x:xs) (y:ys) path acc c = do
  if num_tex y == 0 then load_bitmap0 (x:xs) ys path acc 1
  else do
    contents <- BS.readFile (path ++ x)
    if c == (num_tex y) then do
      load_bitmap0 xs ys path (acc ++ [load_bitmap1 contents (BS.empty) (fromIntegral (tex_w y)) (fromIntegral (tex_h y)) 0 0]) 1
    else do
      load_bitmap0 xs (y:ys) path (acc ++ [load_bitmap1 contents (BS.empty) (fromIntegral (tex_w y)) (fromIntegral (tex_h y)) 0 0]) (c + 1)

load_bitmap1 :: BS.ByteString -> BS.ByteString -> Int -> Int -> Int -> Int -> BS.ByteString
load_bitmap1 bs0 bs1 w h pad y =
  if y == h then bs1
  else load_bitmap1 (BS.drop (3 * w) bs0) (BS.append bs1 (BS.take ((3 * w) - pad) bs0)) w h pad (y + 1)

load_bitmap2 :: GLsizei -> GLsizei -> Ptr CChar -> IO ()
load_bitmap2 w h p_tex = do
  glTexImage2D GL_TEXTURE_2D 0 (fromIntegral GL_RGB) w h 0 GL_RGB GL_UNSIGNED_BYTE p_tex

-- These two functions load vertex data and bind OpenGL vertex array objects and texture objects, which are used to render all environmental models.
setup_object :: [Object] -> [[Int]] -> [Float] -> [GLushort] -> [BS.ByteString] -> Ptr GLuint -> IO ()
setup_object [] _ vertex element bs_tex p_bind = return ()
setup_object (x:xs) (y:ys) vertex element bs_tex p_bind = do
  glGenVertexArrays 1 (plusPtr p_bind ((ident x) * gluint))
  vao <- peekElemOff p_bind (ident x)
  p0 <- mallocBytes gluint
  p1 <- mallocBytes gluint
  p2 <- mallocBytes (glfloat * y !! 1)
  p3 <- mallocBytes (glushort * y !! 3)
  glGenBuffers 1 p0
  glGenBuffers 1 p1
  a_buf <- peek p0
  e_buf <- peek p1
  load_array (take (y !! 1) (drop (y !! 0) vertex)) p2 0
  load_array (take (y !! 3) (drop (y !! 2) element)) p3 0
  glBindVertexArray vao
  glBindBuffer GL_ARRAY_BUFFER a_buf
  glBufferData GL_ARRAY_BUFFER (unsafeCoerce (plusPtr zero_ptr (glfloat * y !! 1)) :: GLsizeiptr) p2 GL_STREAM_DRAW
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER e_buf
  glBufferData GL_ELEMENT_ARRAY_BUFFER (unsafeCoerce (plusPtr zero_ptr (glushort * y !! 3)) :: GLsizeiptr) p3 GL_STREAM_DRAW
  free p0; free p1; free p2; free p3
  glVertexAttribPointer 0 4 GL_FLOAT 0 0 zero_ptr
  if num_tex x > 0 then do
    glVertexAttribPointer 1 2 GL_FLOAT 0 0 (plusPtr zero_ptr ((att_offset x) * 4 * glfloat))
    bind_texture (take (num_tex x) bs_tex) (plusPtr p_bind ((ident x) * gluint + gluint)) (tex_w x) (tex_h x) 0
    glVertexAttribPointer 2 3 GL_FLOAT 0 0 (plusPtr zero_ptr ((att_offset x) * 6 * glfloat))
    glEnableVertexAttribArray 0
    glEnableVertexAttribArray 1
    glEnableVertexAttribArray 2
    setup_object xs ys vertex element (drop (num_tex x) bs_tex) p_bind
  else do
    glVertexAttribPointer 1 4 GL_FLOAT 0 0 (plusPtr zero_ptr ((att_offset x) * 4 * glfloat))
    glVertexAttribPointer 2 3 GL_FLOAT 0 0 (plusPtr zero_ptr ((att_offset x) * 8 * glfloat))
    glEnableVertexAttribArray 0
    glEnableVertexAttribArray 1
    glEnableVertexAttribArray 2
    setup_object xs ys vertex element bs_tex p_bind

bind_texture :: [BS.ByteString] -> Ptr GLuint -> GLsizei -> GLsizei -> Int -> IO ()
bind_texture [] p_bind w h offset = return ()
bind_texture (x:xs) p_bind w h offset = do
  glGenTextures 1 (plusPtr p_bind (offset * gluint))
  tex <- peek (plusPtr p_bind (offset * gluint))
  glBindTexture GL_TEXTURE_2D tex
  BS.useAsCString (BS.take (fromIntegral (w * h * 3)) (BS.reverse x)) (load_bitmap2 w h)
  glGenerateMipmap GL_TEXTURE_2D
  glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER (fromIntegral GL_NEAREST)
  glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER (fromIntegral GL_NEAREST)
  bind_texture xs p_bind w h (offset + 1)

-- This function manages the rendering of all environmental models and in game messages.  It recurses once per frame rendered and is the central branching point of the rendering thread.
show_frame :: HDC -> (UArray Int Word32, Int) -> UArray Int Int32 -> Ptr GLfloat -> (Ptr Int, Ptr Int) -> Float -> Float -> Float -> Int -> Int -> MVar (Play_state0, Array (Int, Int, Int) Wall_grid, Save_state) -> Array (Int, Int, Int) Wall_grid -> Array (Int, Int, Int) Floor_grid -> Array (Int, Int, Int) (Int, [Int]) -> UArray (Int, Int) Float -> Matrix Float -> Array Int (Int, [Int]) -> IO ([Int], Save_state)
show_frame hdc p_bind uniform p_mt_matrix filter_table u v w a a' state_ref w_grid f_grid obj_grid look_up camera_to_clip msg_queue =
  let survey0 = multi_survey (mod_angle a (-92)) 183 u v (truncate u) (truncate v) w_grid f_grid obj_grid look_up 2 0 [] []
      survey1 = multi_survey (mod_angle (mod_angle a' a) 222) 183 (fst view_circle') (snd view_circle') (truncate (fst view_circle')) (truncate (snd view_circle')) w_grid f_grid obj_grid look_up 2 0 [] []
      view_circle' = view_circle u v 2 (mod_angle a a') look_up
      world_to_clip0 = multStd camera_to_clip (world_to_camera (-u) (-v) (-w) a look_up)
      world_to_clip1 = multStd camera_to_clip (world_to_camera (- (fst view_circle')) (- (snd view_circle')) (-w) (mod_angle (mod_angle a' a) 314) look_up)
  in do
  p_state <- takeMVar state_ref
  glClear (GL_COLOR_BUFFER_BIT .|. GL_DEPTH_BUFFER_BIT)
  if view_mode (fst__ p_state) == 0 then load_array (toList world_to_clip0) (castPtr p_mt_matrix) 0
  else do
    load_array (toList world_to_clip1) (castPtr p_mt_matrix) 0
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 2)))
    glUniformMatrix4fv (coerce (uniform ! 40)) 1 1 (castPtr p_mt_matrix)
    glUniform1i (coerce (uniform ! 50)) (fromIntegral (mod (fst__ (game_clock (fst__ p_state))) 240))
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 1)))
    glUniformMatrix4fv (coerce (uniform ! 52)) 1 1 (castPtr p_mt_matrix)
    show_player uniform p_bind (plusPtr p_mt_matrix (glfloat * 80)) u v w a look_up (rend_mode (fst__ p_state))
  if rend_mode (fst__ p_state) == 0 then do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 7)))
    glUniform1i (coerce (uniform ! 9)) (fromIntegral (mod (fst__ (game_clock (fst__ p_state))) 240))
    glUniformMatrix4fv (coerce (uniform ! 1)) 1 1 (castPtr p_mt_matrix)
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 6)))
    glUniform1i (coerce (uniform ! 20)) (fromIntegral (mod (fst__ (game_clock (fst__ p_state))) 240))
    glUniformMatrix4fv (coerce (uniform ! 12)) 1 1 (castPtr p_mt_matrix)
  else do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 5)))
    glUniformMatrix4fv (coerce (uniform ! 24)) 1 1 (castPtr p_mt_matrix)
    glUniform4f (coerce (uniform ! 26)) (coerce u) (coerce v) (coerce w) 1
    glUniform1i (coerce (uniform ! 27)) (fromIntegral (torch_t_limit (fst__ p_state) - (fst__ (game_clock (fst__ p_state)) - torch_t0 (fst__ p_state))))
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 4)))
    glUniformMatrix4fv (coerce (uniform ! 30)) 1 1 (castPtr p_mt_matrix)
    glUniform4f (coerce (uniform ! 32)) (coerce u) (coerce v) (coerce w) 1
    glUniform1i (coerce (uniform ! 33)) (fromIntegral (torch_t_limit (fst__ p_state) - (fst__ (game_clock (fst__ p_state)) - torch_t0 (fst__ p_state))))
  glBindVertexArray (unsafeCoerce ((fst p_bind) ! 0))
  if view_mode (fst__ p_state) == 0 then do
    filtered_surv0 <- filter_surv (fst survey0) [] (fst filter_table) (third_ (game_clock (fst__ p_state)))
    filtered_surv1 <- filter_surv (snd survey0) [] (snd filter_table) (third_ (game_clock (fst__ p_state)))
    show_walls filtered_surv0 uniform p_bind (plusPtr p_mt_matrix (glfloat * 16)) u v w a look_up (rend_mode (fst__ p_state))
    show_object filtered_surv1 uniform p_bind (plusPtr p_mt_matrix (glfloat * 48)) u v w a look_up (rend_mode (fst__ p_state))
  else do
    filtered_surv0 <- filter_surv (fst survey1) [] (fst filter_table) (third_ (game_clock (fst__ p_state)))
    filtered_surv1 <- filter_surv (snd survey1) [] (snd filter_table) (third_ (game_clock (fst__ p_state)))
    show_walls filtered_surv0 uniform p_bind (plusPtr p_mt_matrix (glfloat * 16)) u v w a look_up (rend_mode (fst__ p_state))
    show_object filtered_surv1 uniform p_bind (plusPtr p_mt_matrix (glfloat * 48)) u v w a look_up (rend_mode (fst__ p_state))
  msg_residue <- handle_message0 (handle_message1 (message_ (fst__ p_state)) msg_queue 0 3) uniform p_bind 0
  if fst msg_residue == 1 then return ([1], third_ p_state)
  else if fst msg_residue == 2 then do
    threadDelay 5000000
    return ([2], third_ p_state)
  else if fst msg_residue == 3 then return ([3], third_ p_state)
  else if fst msg_residue > 3 then return (([0] ++ (snd (head (message_ (fst__ p_state))))), third_ p_state)
  else do
    Main.swapBuffers hdc
    show_frame hdc p_bind uniform p_mt_matrix filter_table (pos_u (fst__ p_state)) (pos_v (fst__ p_state)) (pos_w (fst__ p_state)) (angle (fst__ p_state)) (view_angle (fst__ p_state)) state_ref (snd__ p_state) f_grid obj_grid look_up camera_to_clip (snd msg_residue)

--These two functions iterate through the message queue received from the game logic thread.  They manage the appearance and expiry of on screen messages and detect special event messages,
--such as are received when the user opts to return to the main menu.
handle_message1 :: [(Int, [Int])] -> Array Int (Int, [Int]) -> Int -> Int -> (Int, Array Int (Int, [Int]))
handle_message1 [] msg_queue i0 i1 = (0, msg_queue)
handle_message1 (x:xs) msg_queue i0 i1 =
  if fst x < 0 then (abs (fst x), msg_queue)
  else if head (snd x) == -1 then
    if fst (msg_queue ! i1) == 0 && i1 < 5 then handle_message1 xs (msg_queue // [(i1, x)]) i0 (i1 + 1)
    else if fst (msg_queue ! i1) == 0 && i1 == 5 then handle_message1 xs (msg_queue // [(i1, x)]) i0 3
    else if fst (msg_queue ! i1) > 0 && i1 < 5 then handle_message1 (x:xs) msg_queue i0 (i1 + 1)
    else handle_message1 xs (msg_queue // [(3, x)]) i0 4
  else
    if fst (msg_queue ! i0) == 0 && i0 < 2 then handle_message1 xs (msg_queue // [(i0, x)]) (i0 + 1) i1
    else if fst (msg_queue ! i0) == 0 && i0 == 2 then handle_message1 xs (msg_queue // [(i0, x)]) 0 i1
    else if fst (msg_queue ! i0) > 0 && i0 < 2 then handle_message1 (x:xs) msg_queue (i0 + 1) i1
    else handle_message1 xs (msg_queue // [(0, x)]) 1 i1

handle_message0 :: (Int, Array Int (Int, [Int])) -> UArray Int Int32 -> (UArray Int Word32, Int) -> Int -> IO (Int, Array Int (Int, [Int]))
handle_message0 msg_queue uniform p_bind i =
  let h_pos = \x -> if x < 3 then -0.96
                    else 0.64
      msg_queue_ = (snd msg_queue) ! i
  in do
  if fst msg_queue > 0 then return msg_queue
  else if i > 5 then return msg_queue
  else if fst ((snd msg_queue) ! i) > 0 then do
    show_text (tail (snd ((snd msg_queue) ! i))) 0 933 uniform p_bind (h_pos i) (0.9 - 0.05 * fromIntegral (mod i 3)) zero_ptr
    handle_message0 (0, (snd msg_queue) // [(i, ((fst msg_queue_) - 1, snd msg_queue_))]) uniform p_bind (i + 1)
  else handle_message0 msg_queue uniform p_bind (i + 1)

-- These three functions pass transformation matrices to the shaders and make the GL draw calls that render models.
show_walls :: [Wall_place] -> UArray Int Int32 -> (UArray Int Word32, Int) -> Ptr GLfloat -> Float -> Float -> Float -> Int -> UArray (Int, Int) Float -> Int -> IO ()
show_walls [] uniform p_bind p_mt_matrix u v w a look_up mode = return ()
show_walls (x:xs) uniform p_bind p_mt_matrix u v w a look_up mode = do
  if isNull x == False then do
    load_array (toList (model_to_world (translate_u x) (translate_v x) (translate_w x) 0 False look_up)) (castPtr p_mt_matrix) 0
    load_array (toList (world_to_model (translate_u x) (translate_v x) (translate_w x) 0 False look_up)) (castPtr p_mt_matrix) 16
    if texture_ x == 0 && mode == 0 then do
      glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 7)))
      glUniformMatrix4fv (coerce (uniform ! 0)) 1 1 p_mt_matrix
      glUniformMatrix4fv (coerce (uniform ! 2)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    else if texture_ x > 0 && texture_ x < (snd p_bind) && mode == 0 then do
      glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 6)))
      glBindTexture GL_TEXTURE_2D (unsafeCoerce ((fst p_bind) ! texture_ x))
      glUniformMatrix4fv (coerce (uniform ! 11)) 1 1 p_mt_matrix
      glUniformMatrix4fv (coerce (uniform ! 13)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    else if texture_ x == 0 && mode == 1 then do
      glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 5)))
      glUniformMatrix4fv (coerce (uniform ! 23)) 1 1 p_mt_matrix
      glUniformMatrix4fv (coerce (uniform ! 25)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    else if texture_ x > 0 && texture_ x < (snd p_bind) && mode == 1 then do
      glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 4)))
      glBindTexture GL_TEXTURE_2D (unsafeCoerce ((fst p_bind) ! texture_ x))
      glUniformMatrix4fv (coerce (uniform ! 29)) 1 1 p_mt_matrix
      glUniformMatrix4fv (coerce (uniform ! 31)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    else do
      putStr "\nshow_walls: Invalid wall_place texture reference in map..."
      show_walls xs uniform p_bind p_mt_matrix u v w a look_up mode
    if Build_model.rotate x < 2 then glDrawElements GL_TRIANGLES 36 GL_UNSIGNED_SHORT (plusPtr zero_ptr (glushort * 36))
    else glDrawElements GL_TRIANGLES 36 GL_UNSIGNED_SHORT zero_ptr
    show_walls xs uniform p_bind p_mt_matrix u v w a look_up mode
  else show_walls xs uniform p_bind p_mt_matrix u v w a look_up mode

show_object :: [Obj_place] -> UArray Int Int32 -> (UArray Int Word32, Int) -> Ptr GLfloat -> Float -> Float -> Float -> Int -> UArray (Int, Int) Float -> Int -> IO ()
show_object [] uniform p_bind p_mt_matrix u v w a look_up mode = return ()
show_object (x:xs) uniform p_bind p_mt_matrix u v w a look_up mode = do
  load_array (toList (model_to_world (u__ x) (v__ x) (w__ x) 0 False look_up)) (castPtr p_mt_matrix) 0
  load_array (toList (world_to_model (u__ x) (v__ x) (w__ x) 0 False look_up)) (castPtr p_mt_matrix) 16
  if ident_ x < (snd p_bind) && texture__ x == 0 && mode == 0 then do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 7)))
    glUniformMatrix4fv (coerce (uniform ! 0)) 1 1 p_mt_matrix
    glUniformMatrix4fv (coerce (uniform ! 2)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
  else if (ident_ x) + (texture__ x) < snd p_bind && texture__ x > 0 && mode == 0 then do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 6)))
    glUniformMatrix4fv (coerce (uniform ! 11)) 1 1 p_mt_matrix
    glUniformMatrix4fv (coerce (uniform ! 13)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    glBindTexture GL_TEXTURE_2D (unsafeCoerce ((fst p_bind) ! ((ident_ x) + (texture__ x))))
  else if ident_ x < (snd p_bind) && texture__ x == 0 && mode == 1 then do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 5)))
    glUniformMatrix4fv (coerce (uniform ! 23)) 1 1 p_mt_matrix
    glUniformMatrix4fv (coerce (uniform ! 25)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
  else if (ident_ x) + (texture__ x) < snd p_bind && texture__ x > 0 && mode == 1 then do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 4)))
    glUniformMatrix4fv (coerce (uniform ! 29)) 1 1 p_mt_matrix
    glUniformMatrix4fv (coerce (uniform ! 31)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    glBindTexture GL_TEXTURE_2D (unsafeCoerce ((fst p_bind) ! ((ident_ x) + (texture__ x))))
  else do
    putStr "\nshow_object: Invalid obj_place object or texture reference in map..."
    show_object xs uniform p_bind p_mt_matrix u v w a look_up mode
  glBindVertexArray (unsafeCoerce ((fst p_bind) ! (ident_ x)))
  glDrawElements GL_TRIANGLES (coerce (num_elem x)) GL_UNSIGNED_SHORT zero_ptr
  show_object xs uniform p_bind p_mt_matrix u v w a look_up mode

show_player :: UArray Int Int32 -> (UArray Int Word32, Int) -> Ptr GLfloat -> Float -> Float -> Float -> Int -> UArray (Int, Int) Float -> Int -> IO ()
show_player uniform p_bind p_mt_matrix u v w a look_up mode = do
  load_array (toList (model_to_world u v w a True look_up)) (castPtr p_mt_matrix) 0
  load_array (toList (world_to_model u v w a True look_up)) (castPtr p_mt_matrix) 16
  load_array (toList (rotation_w a look_up)) (castPtr p_mt_matrix) 32
  if mode == 0 then do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 2)))
    glUniformMatrix4fv (coerce (uniform ! 39)) 1 1 p_mt_matrix
    glUniformMatrix4fv (coerce (uniform ! 41)) 1 1 (plusPtr p_mt_matrix (glfloat * 16))
    glUniformMatrix4fv (coerce (uniform ! 42)) 1 1 (plusPtr p_mt_matrix (glfloat * 32))
  else do
    glUseProgram (unsafeCoerce ((fst p_bind) ! ((snd p_bind) - 1)))
    glUniformMatrix4fv (coerce (uniform ! 51)) 1 1 p_mt_matrix
  glBindVertexArray (unsafeCoerce ((fst p_bind) ! 1024))
  glBindTexture GL_TEXTURE_2D (unsafeCoerce ((fst p_bind) ! 1025))
  glDrawElements GL_TRIANGLES 36 GL_UNSIGNED_SHORT zero_ptr
