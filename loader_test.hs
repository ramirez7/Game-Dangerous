module Main where

import System.IO
import System.Environment
import qualified Data.ByteString.Lazy as LBS
import Data.Binary
import qualified Data.Sequence as SEQ
import Data.Either
import Data.Int
import Build_model

def_obj_place_ = ((0, 0, 0), Nothing) :: ((Int, Int, Int), Maybe Obj_place)
def_f_grid_ = ((0, 0, 0), def_f_grid) :: ((Int, Int, Int), Floor_grid)
def_obj_grid_ = ((0, 0, 0), def_obj_grid) :: ((Int, Int, Int), (Int, [Int]))

decode_sequence :: Binary a => Int -> a -> LBS.ByteString -> SEQ.Seq a -> SEQ.Seq a
decode_sequence c def bs diff_seq =
  let result = decodeOrFail bs
      tested_result = if (isLeft result) == True then error ("\ndecode_sequence: " ++ third_ (fromLeft (LBS.empty, 0, "def") result) ++ "\nblock offset: " ++ show c)
                      else fromRight (LBS.empty, 0, def) result
  in
  if LBS.length bs == 0 then diff_seq
  else decode_sequence (c + 1) def (fst__ tested_result) (diff_seq SEQ.>< SEQ.singleton (third_ tested_result))

main = do
  args <- getArgs
  contents <- LBS.readFile (args !! 0)
  examine_save_file 0 contents

examine_save_file :: Int -> LBS.ByteString -> IO ()
examine_save_file c bs = do
  if LBS.length bs == 0 then error "\nEnd of file encountered unexpectedly."
  else if c == 0 then do
    putStr ("\n\nObj_place sequence section size: " ++ show (fromIntegral ((decode (LBS.take 8 bs)) :: Int)))
    putStr ("\nObj_place sequence: " ++ show (decode_sequence 0 def_obj_place_ (LBS.take (fromIntegral ((decode (LBS.take 8 bs)) :: Int)) (LBS.drop 8 bs)) SEQ.empty))
    examine_save_file 1 (LBS.drop (8 + fromIntegral ((decode (LBS.take 8 bs)) :: Int)) bs)
  else if c == 1 then do
    putStr ("\n\nFloor_grid sequence: " ++ show (decode_sequence 0 def_f_grid_ (LBS.take (fromIntegral ((decode (LBS.take 8 bs)) :: Int)) (LBS.drop 8 bs)) SEQ.empty))
    examine_save_file 2 (LBS.drop (8 + fromIntegral ((decode (LBS.take 8 bs)) :: Int)) bs)
  else if c == 2 then do
    putStr ("\n\nObj_grid sequence: " ++ show (decode_sequence 0 def_obj_grid_ (LBS.take (fromIntegral ((decode (LBS.take 8 bs)) :: Int)) (LBS.drop 8 bs)) SEQ.empty))
    examine_save_file 3 (LBS.drop (8 + fromIntegral ((decode (LBS.take 8 bs)) :: Int)) bs)
  else if c == 3 then do
    putStr ("\n\nPlay_state0: " ++ show ((decode (LBS.take (fromIntegral ((decode (LBS.take 8 bs)) :: Int)) (LBS.drop 8 bs))) :: Play_state0))
    examine_save_file 4 (LBS.drop (8 + fromIntegral ((decode (LBS.take 8 bs)) :: Int)) bs)
  else putStr ("\n\nPlay_state1: " ++ show ((decode (LBS.take (fromIntegral ((decode (LBS.take 8 bs)) :: Int)) (LBS.drop 8 bs))) :: Play_state1))
