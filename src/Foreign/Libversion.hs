{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Bindings to libversion
module Foreign.Libversion
  ( VersionString (..),
    VersionFlag (..),
    compareVersion,
    compareVersion',
  )
where

import Data.ByteString (ByteString, useAsCString)
import Data.Coerce (coerce)
import Data.String (IsString)
import Foreign.C (CInt (..), CString)
import System.IO.Unsafe (unsafePerformIO)

foreign import ccall unsafe "version_compare2"
  _compareVersion :: CString -> CString -> CInt

foreign import ccall unsafe "version_compare4"
  _compareVersion' :: CString -> CString -> CInt -> CInt -> CInt

-- | newtype around 'ByteString' that uses 'compareVersion' to implement the 'Ord' instance
newtype VersionString = VersionString {unVersionString :: ByteString}
  deriving newtype (Show, Semigroup, Monoid, IsString)

instance Ord VersionString where
  compare = coerce compareVersion

instance Eq VersionString where
  v1 == v2 = v1 `compare` v2 == EQ

-- | Flags to tune the comparison behavior
data VersionFlag
  = NoFlag
  | -- | /p/ letter is treated as /patch/ (post-release) instead of /pre/ (pre-release).
    PIsPatch
  | -- | any letter sequence is treated as post-release (useful for handling patchsets as in @1.2foopatchset3.barpatchset4@).
    AnyIsPatch
  | -- | derive lowest possible version with the given prefix.
    --   For example, lower bound for @1.0@ is such imaginary version @?@ that
    --   it's higher than any release before @1.0@ and lower than any prerelease of @1.0@.
    --   E.g. @0.999@ < lower bound(@1.0@) < @1.0alpha0@.
    LowerBound
  | -- | derive highest possible version with the given prefix. Oppisite of 'LowerBound'.
    UpperBound
  deriving (Show, Eq)

instance Enum VersionFlag where
  fromEnum NoFlag = 0
  fromEnum PIsPatch = 1
  fromEnum AnyIsPatch = 2
  fromEnum LowerBound = 4
  fromEnum UpperBound = 8
  toEnum i
    | i == 0 = NoFlag
    | i == 1 = PIsPatch
    | i == 2 = AnyIsPatch
    | i == 4 = LowerBound
    | i == 8 = UpperBound
    | otherwise = error $ "VersionFlag: fromEnum called with bad argument " <> show i

-- | Compare version strings @v1@ and @v2@
compareVersion :: ByteString -> ByteString -> Ordering
compareVersion ver1 ver2 =
  unsafePerformIO $
    useAsCString ver1 $ \v1 ->
      useAsCString ver2 $ \v2 ->
        pure $
          case _compareVersion v1 v2 of
            1 -> GT
            0 -> EQ
            -1 -> LT
            v -> error $ "unknown return value " <> show v <> " from version_compare2"

-- | Compare version strings @v1@ and @v2@ with additional flags
compareVersion' :: VersionFlag -> VersionFlag -> ByteString -> ByteString -> Ordering
compareVersion' flag1 flag2 ver1 ver2 =
  unsafePerformIO $
    useAsCString ver1 $ \v1 ->
      useAsCString ver2 $ \v2 ->
        pure $
          case _compareVersion' v1 v2 (toEnum $ fromEnum flag1) (toEnum $ fromEnum flag2) of
            1 -> GT
            0 -> EQ
            -1 -> LT
            v -> error $ "unknown return value " <> show v <> " from version_compare4"