package main

/*
 * Copyright (c) 2010-2012, Cyril Adrian <cyril.adrian@gmail.com> All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that
 * the following conditions are met:
 *
 *  - Redistributions of source code must retain the above copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 *  - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
 *    following - disclaimer in the documentation and/or other materials provided - with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"regexp"
)

type command struct {
	cmd *exec.Cmd
	out io.ReadCloser
	err io.ReadCloser
}

func treat_data(data chan []byte, callback func(string) error) {
	var buffer bytes.Buffer
	for {
		for _, c := range <-data {
			if c == '\n' {
				err := callback(buffer.String())
				if err != nil {
					log.Fatalln(err)
				}
				buffer.Reset()
			} else {
				buffer.WriteByte(c)
			}
		}
	}
}

func start(callback func(string) error, name string, arg ...string) (result *command, err error) {
	result = &command{}

	result.cmd = exec.Command(name, arg...)

	result.out, err = result.cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}

	result.err, err = result.cmd.StderrPipe()
	if err != nil {
		return nil, err
	}

	err = result.cmd.Start()
	if err != nil {
		return nil, err
	}

	chan_out := make(chan []byte)
	chan_err := make(chan []byte)

	go treat_data(chan_out, callback)
	go treat_data(chan_err, callback)

	go func() {
		var n int
		p := make([]byte, 4096)
		for {
			n, _ = result.out.Read(p)
			if n > 0 {
				chan_out <- p[:n]
			}
			n, _ = result.err.Read(p)
			if n > 0 {
				chan_err <- p[:n]
			}
		}
	}()

	return
}

func (self *command) Wait() error {
	return self.cmd.Wait()
}

type context struct {
	file string
	cmd []*command
}

func callback_build() func(line string) error {
	build_re := regexp.MustCompile("^(?P<file>[^#:][^:]*):(?P<line>[0-9]+): (?P<desc>.*)$")
	return func(line string) error {
		if build_re.MatchString(line) {
			fmt.Println(line)
		}
		return nil
	}
}

func (self *context) Start(callback func(string) error) {
	cmd, err := start(callback, "go", "build", "-o", "/dev/null", self.file)
	if err == nil {
		self.cmd = append(self.cmd, cmd)
	} else {
		log.Fatalln(err)
	}
}

func (self *context) Wait() {
	for _, cmd := range self.cmd {
		cmd.Wait()
	}
}

func main() {
	var file string

	if (len(os.Args) < 2) {
		log.Fatalf("Usage: %s <filename>\n", os.Args[0])
	} else if (os.Args[1] == "--") {
		if (len(os.Args) < 3) {
			log.Fatalf("Usage: %s <filename>\n", os.Args[0])
		}
		file = os.Args[2]
	} else {
		file = os.Args[1]
	}

	ctx := &context{
		file: file,
		cmd: make([]*command, 0, 10),
	}

	ctx.Start(callback_build())
	ctx.Wait()
}
