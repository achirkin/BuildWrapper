{-# LANGUAGE DeriveDataTypeable,OverloadedStrings #-}
module Language.Haskell.BuildWrapper.CMD where

import Language.Haskell.BuildWrapper.API
import Language.Haskell.BuildWrapper.Base
import Control.Monad
import Control.Monad.State
import System.Console.CmdArgs hiding (Verbosity(..))

import Data.Aeson
import qualified Data.ByteString.Lazy as BS
import qualified Data.Text as T

import System.FilePath

type CabalFile = FilePath
type CabalPath = FilePath
type TempFolder = FilePath

data BWCmd=Synchronize {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, force::Bool}
        | Synchronize1 {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, force::Bool, file:: FilePath}
        | Write {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, file:: FilePath, contents::String}  
        | Configure {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile,verbosity::Verbosity,cabalTarget::WhichCabal}
        | Build {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile,verbosity::Verbosity,output::Bool,cabalTarget::WhichCabal}
        | Outline {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, file:: FilePath} 
        | TokenTypes {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, file:: FilePath} 
        | Occurrences {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, file:: FilePath,token::String}
        | ThingAtPoint {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, file:: FilePath, line::Int, column::Int, qualify::Bool, typed::Bool}
        | NamesInScope {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile, file:: FilePath} 
        | Dependencies {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile}
        | Components {tempFolder::TempFolder, cabalPath::CabalPath, cabalFile::CabalFile}
    deriving (Show,Read,Data,Typeable)    
  
 
tf=".dist-buildwrapper" &= typDir &= help "temporary folder, relative to cabal file folder"
cp="cabal" &= typFile &= help "location of cabal executable" 
cf=def &= typFile &= help "cabal file" 
fp=def &= typFile &= help "relative path of file to process"
ff=def &= help "overwrite newer file"
 
v=Normal &= help "verbosity"
wc=Target &= help "which cabal file to use: original or temporary"

msynchronize = Synchronize tf cp cf ff
msynchronize1 = Synchronize1 tf cp cf ff fp
mconfigure = Configure tf cp cf v wc
mwrite= Write tf cp cf fp (def &= help "file contents")
mbuild = Build tf cp cf v (def &= help "output compilation and linking result") wc
moutline = Outline tf cp cf fp
mtokenTypes= TokenTypes tf cp cf fp
moccurrences=Occurrences tf cp cf fp (def &= help "text to search occurrences of" &= name "token")
mthingAtPoint=ThingAtPoint tf cp cf fp 
        (def &= help "line" &= name "line")
        (def &= help "column" &= name "column")
        (def &= help "qualify results")
        (def &= help "type results")
mnamesInScope=NamesInScope tf cp cf fp 
mdependencies=Dependencies tf cp cf
mcomponents=Components tf cp cf

cmdMain = (cmdArgs $ 
                modes [msynchronize, msynchronize1, mconfigure,mwrite,mbuild, moutline, mtokenTypes,moccurrences,mthingAtPoint,mnamesInScope,mdependencies,mcomponents]
                &= helpArg [explicit, name "help", name "h"]
                &= help "buildwrapper executable"
                &= program "buildwrapper"
                )
        >>= handle
        where 
                handle ::BWCmd -> IO ()
                handle (Synchronize tf cp cf ff )=run tf cp cf (synchronize ff)
                handle (Synchronize1 tf cp cf ff fp)=run tf cp cf (synchronize1 ff fp)
                handle (Write tf cp cf fp s)=run tf cp cf (write fp s)
                handle (Configure tf cp cf v wc)=runV v tf cp cf (configure wc)
                handle (Build tf cp cf v output wc)=runV v tf cp cf (build output wc)
                handle (Outline tf cp cf fp)=run tf cp cf (getOutline fp)
                handle (TokenTypes tf cp cf fp)=run tf cp cf (getTokenTypes fp)
                handle (Occurrences tf cp cf fp token)=run tf cp cf (getOccurrences fp token)
                handle (ThingAtPoint tf cp cf fp line column qual typed)=run tf cp cf (getThingAtPoint fp line column qual typed)
                handle (NamesInScope tf cp cf fp)=run tf cp cf (getNamesInScope fp)
                handle (Dependencies tf cp cf)=run tf cp cf getCabalDependencies
                handle (Components tf cp cf)=run tf cp cf getCabalComponents
                run:: (ToJSON a) => FilePath -> FilePath -> FilePath -> StateT BuildWrapperState IO a -> IO ()
                run = runV Normal
                runV:: (ToJSON a) => Verbosity -> FilePath -> FilePath -> FilePath -> StateT BuildWrapperState IO a -> IO ()
                runV v tf cp cf f=(evalStateT f (BuildWrapperState tf cp cf v))
                                >>= BS.putStrLn . BS.append "build-wrapper-json:" . encode
                        