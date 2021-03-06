{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
module Opaleye.X
  ( MonadDB(..)
  , safeInsertOne, safeInsertOneReturningId
  , selectOne_, select_
  , selectToString
  ) where

import Control.Exception               (Exception, throwIO)
import Control.Monad.Catch             (catch)

import Data.Int                        (Int64)
import Data.Maybe                      (fromMaybe, listToMaybe)
import Data.Text                       (Text)
import Data.Text.Encoding              (decodeUtf8)

import Data.Profunctor.Product.Default (Default)
import Database.PostgreSQL.Simple      (Connection, SqlError(..))
import Opaleye


class (Monad m) => MonadDB m where
   insertOne :: Default Constant hW pW => Table pW pR -> hW -> m Int64
   insertOneReturningId
     :: (Default Constant hW pW)
     => Table pW pR -> hW -> (pR -> Column SqlInt4) -> m (Maybe Int)
   selectOne :: (Default FromFields a b) => Select a -> m (Maybe b)
   select :: (Default FromFields a b) => Select a -> m [b]

newtype DBError = UniqueContraintError Text
  deriving (Show)

instance Exception DBError

selectToString :: Default Unpackspec a a => Select a -> String
selectToString = fromMaybe "Empty query" . showSqlForPostgres

selectOne_ :: (Default FromFields a b) => Connection -> Select a -> IO (Maybe b)
selectOne_ conn = fmap listToMaybe . runSelect conn . limit 1

select_ :: (Default FromFields a b) => Connection -> Select a -> IO [b]
select_ = runSelect

safeInsertOne
  :: Default Constant hW pW
  => Connection -> Table pW pR -> hW -> IO (Either DBError Int64)
safeInsertOne conn t h = runInsertSafe conn Insert
  { iTable = t
  , iRows = [toFields h]
  , iReturning  = rCount
  , iOnConflict = Nothing
  }

safeInsertOneReturningId
  :: (Default Constant hW pW)
  => Connection -> Table pW pR -> hW -> (pR -> Column SqlInt4) -> IO (Either DBError (Maybe Int))
safeInsertOneReturningId conn t h rId = fmap listToMaybe <$> runInsertSafe conn Insert
  { iTable = t
  , iRows = [toFields h]
  , iReturning  = rReturning rId
  , iOnConflict = Nothing
  }

runInsertSafe :: Connection -> Insert a -> IO (Either DBError a)
runInsertSafe conn = flip catch handleInsertErrors  . correctInsert
  where
    correctInsert = fmap Right . runInsert_ conn

handleInsertErrors :: SqlError -> IO (Either DBError a)
handleInsertErrors err@SqlError{ sqlState, sqlErrorDetail } =
  let errorMessage = decodeUtf8 sqlErrorDetail
      reportError  = return . Left
  in  case sqlState of
        "23505" -> reportError $ UniqueContraintError errorMessage
        _       -> throwIO err
