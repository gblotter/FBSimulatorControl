/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import Foundation

public extension Command {
  static func getHelp() -> String {
    return "HElp"
  }
}

//private protocol Help {
//  func getA() -> String
//}
//
//extension Configuration : Help {
//  public func getHelp() -> String {
//    return "[--device-set <path-to-device-set>]"
//  }
//}

//extension Command : Help {
//  private func getHelp() -> Void {
//    let help = [Command.Help, Command.List(.State(.Shutdown), .UDID)]
//      .map(Command.commandHelp)
//      .joinWithSeparator("\n")
//    print(help)
//  }
//  
//  public static func getAllHelp() -> String {
//    let commands = [
//      Command(
//    ]
//  }
//  
//  private static func getGrammar() -> String {
//    
//  }
//  
//  private static
//}

//switch (command) {
//case .Help: return "Prints Help"
//case .List: return "Lists Simulators"
//case .Boot: return "Boots Simulators"
//case .Shutdown: return "Shuts Down Simulators"
//}


