# Copyright 2021 Ross Light
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/0c408a087b4751c887e463e3848512c12017be25.tar.gz") {}
}:

{
  inherit pkgs;

  redo-zombiezen = pkgs.callPackage ./redo-zombiezen.nix {};

  # Extra tools for running tests and the like.
  devTools = {
    inherit (pkgs) bash python310 rust-analyzer;

    rustLibSrc = pkgs.rust.packages.stable.rustPlatform.rustLibSrc;
  };
}
