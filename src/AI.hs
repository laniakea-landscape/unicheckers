module AI (
  handleAI
) where

import State
import Data.Maybe (mapMaybe)
import System.Random

type History = [State]

generator :: StdGen
generator = mkStdGen 12  -- $ getClockTime >>= (\(TOD _ pico) -> return pico)


handleAI :: State -> State
handleAI s =
    newState { status =    if isStop newState then Stopped else InProcess
             , winner =    if isStop newState
                           then Just (if isWin' newState then aiTeam newState else nextTeam $ aiTeam newState)
                           else Nothing
             , inOptions = isStop newState
             }
  where
    vars             = calculateHistoryVariants [([s], 0)] (level s * 2 - 1)
    maxRate          = maximum $ map snd vars
    bestVars         = filter (\var -> snd var == maxRate) vars
    len              = length bestVars
    (rand, _)        = randomR (0, len - 1) generator
    (bestVar, _)     = bestVars!!rand 
    newState         = if isStop s then s else last $ init bestVar


calculateHistoryVariants :: [(History, Int)] -> Int -> [(History, Int)]
calculateHistoryVariants acc num = case num of
    0                        -> acc
    _ | any isWin acc        -> filter isWin acc
    n | not $ all isLoss acc -> calculateHistoryVariants (filter (not . isLoss) acc >>= forkHistory) (n - 1)
    _                        -> acc


isStop :: State -> Bool
isStop s = isWin' s || isLoss' s

isWin' :: State -> Bool
isWin' s = null $ getTeamFigures s $ nextTeam (aiTeam s)

isWin :: (History, Int) -> Bool
isWin hi = isWin' $ head $ fst hi

isLoss' :: State -> Bool
isLoss' s = null $ getTeamFigures s $ aiTeam s

isLoss :: (History, Int) -> Bool
isLoss hi = isLoss' $ head $ fst hi


forkHistory :: (History, Int) -> [(History, Int)]
forkHistory h = map (rate . (: h')) $ getCurrentTeamFigures (head h') >>= processFigure (head h')
  where
    h' = fst h


processFigure :: State -> Figure -> [State]
processFigure s f = mapMaybe (processTurn s f) [(x, y) | x <- [1 .. 8], y <- [1 .. 8]]


processTurn :: State -> Figure -> (Int, Int) -> Maybe State
processTurn s f c = do
    ms      <- selectFigure s f
    (ns, _) <- turnResult (setCursor ms c)
    return ns


rate :: History -> (History, Int)
rate h =
    (h, aiFsn - plFsn + (aiKsn - plKsn) * 2 + (if plFsn == 0 then 100 else 0) - (if aiFsn == 0 then 100 else 0))
  where
    s     = head h
    t     = aiTeam s
    aiFs  = getTeamFigures s t
    plFs  = getTeamFigures s $ nextTeam t
    aiFsn = length aiFs
    plFsn = length plFs
    aiKsn = kingsN aiFs
    plKsn = kingsN plFs


kingsN :: [Figure] -> Int
kingsN fs = length $ filter (\f -> fType f == King) fs