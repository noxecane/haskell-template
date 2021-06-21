{-# LANGUAGE OverloadedStrings #-}

module Routes (runApp, app) where

import Network.Wai (Application)
import qualified Web.Scotty as S


app' :: S.ScottyM ()
app' = S.get "/" $ S.text "hello"

app :: IO Application
app = S.scottyApp app'

runApp :: IO ()
runApp = S.scotty 8080 app'
