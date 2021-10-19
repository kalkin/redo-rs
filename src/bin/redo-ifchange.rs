use failure::Error;
use rusqlite::TransactionBehavior;
use std::io;
use std::path::PathBuf;

use redo::builder::{self, StdinLogReader, StdinLogReaderBuilder};
use redo::logs::LogBuilder;
use redo::{self, log_debug2, log_err, DepMode, Env, JobServer, ProcessState, ProcessTransaction};

fn main() {
    redo::run_program("redo-ifchange", run);
}

fn run() -> Result<(), Error> {
    let mut targets: Vec<String> = std::env::args().skip(1).collect();
    let env = Env::init(targets.as_slice())?;
    let mut ps = ProcessState::init(env)?;
    if ps.is_toplevel() && targets.is_empty() {
        targets.push(String::from("all"));
    }
    let mut _stdin_log_reader: Option<StdinLogReader> = None; // held during operation
    if ps.is_toplevel() && ps.env().log() != 0 {
        builder::close_stdin()?;
        _stdin_log_reader = Some(StdinLogReaderBuilder::default().start(ps.env())?);
    } else {
        LogBuilder::from(ps.env()).setup(ps.env(), io::stderr());
    }

    let mut server;
    {
        let mut ptx = ProcessTransaction::new(&mut ps, TransactionBehavior::Deferred)?;
        let f = if !ptx.state().env().target().as_os_str().is_empty()
            && !ptx.state().env().is_unlocked()
        {
            let mut me = PathBuf::new();
            me.push(ptx.state().env().startdir());
            me.push(ptx.state().env().pwd());
            me.push(ptx.state().env().target());
            let f = redo::File::from_name(
                &mut ptx,
                me.as_os_str().to_str().expect("invalid target name"),
                true,
            )?;
            log_debug2!(
                "TARGET: {:?} {:?} {:?}\n",
                ptx.state().env().startdir(),
                ptx.state().env().pwd(),
                ptx.state().env().target()
            );
            Some(f)
        } else {
            log_debug2!("redo-ifchange: not adding depends.\n");
            None
        };
        server = JobServer::setup(0)?;
        if let Some(mut f) = f {
            for t in targets.iter() {
                f.add_dep(&mut ptx, DepMode::Modified, t)?;
            }
            f.save(&mut ptx)?;
            ptx.commit()?;
        }
    }

    let build_result = server.block_on(builder::run(&mut ps, &mut server.handle(), &targets));
    // TODO(someday): In the original, there's a state.rollback call.
    // Unclear what this is trying to do.
    assert!(ps.is_flushed());
    let return_tokens_result = server.force_return_tokens();
    if let Err(e) = &return_tokens_result {
        log_err!("unexpected error: {}", e);
    }
    build_result.map_err(|e| e.into()).and(return_tokens_result)
}
