import gleeunit
import gleeunit/should
import rad

pub fn main() {
  gleeunit.main()
}

pub fn main_test() {
  rad.main()
  |> should.equal("Radical!")
}
