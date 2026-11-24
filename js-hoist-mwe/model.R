# Age x vaccine-stratum SEIR, discrete time, deterministic
n_age <- parameter(50)
n_vacc <- parameter(3)
beta <- parameter(0.3)
sigma <- parameter(0.2)
gamma <- parameter(0.1)
ageing <- parameter(1 / 365)
vacc_rate <- parameter()
efficacy <- parameter()
contact <- parameter()
S0 <- parameter()
I0 <- parameter()

dim(vacc_rate) <- c(n_age, n_vacc)
dim(efficacy) <- n_vacc
dim(contact) <- c(n_age, n_age)
dim(S0, I0) <- c(n_age, n_vacc)
dim(S, E, I, R) <- c(n_age, n_vacc)
dim(N_age, I_age, lambda) <- n_age
dim(new_inf, new_inc, new_rec, new_vacc) <- c(n_age, n_vacc)
dim(age_in_S, age_in_E, age_in_I, age_in_R) <- c(n_age, n_vacc)

N_age[] <- sum(S[i, ]) + sum(E[i, ]) + sum(I[i, ]) + sum(R[i, ])
I_age[] <- sum(I[i, ])
dim(foi) <- c(n_age, n_age)
foi[, ] <- contact[i, j] * I_age[j] / N_age[j]
lambda[] <- beta * sum(foi[i, ])

new_inf[, ] <- S[i, j] * lambda[i] * (1 - efficacy[j])
new_inc[, ] <- E[i, j] * sigma
new_rec[, ] <- I[i, j] * gamma
new_vacc[, ] <- if (j < n_vacc) S[i, j] * vacc_rate[i, j] else 0

age_in_S[1, ] <- 0
age_in_S[2:n_age, ] <- S[i - 1, j] * ageing
age_in_E[1, ] <- 0
age_in_E[2:n_age, ] <- E[i - 1, j] * ageing
age_in_I[1, ] <- 0
age_in_I[2:n_age, ] <- I[i - 1, j] * ageing
age_in_R[1, ] <- 0
age_in_R[2:n_age, ] <- R[i - 1, j] * ageing

update(S[, ]) <- S[i, j] - new_inf[i, j] - new_vacc[i, j] + (if (j > 1) new_vacc[i, j - 1] else 0) + age_in_S[i, j] - S[i, j] * ageing
update(E[, ]) <- E[i, j] + new_inf[i, j] - new_inc[i, j] + age_in_E[i, j] - E[i, j] * ageing
update(I[, ]) <- I[i, j] + new_inc[i, j] - new_rec[i, j] + age_in_I[i, j] - I[i, j] * ageing
update(R[, ]) <- R[i, j] + new_rec[i, j] + age_in_R[i, j] - R[i, j] * ageing

initial(S[, ]) <- S0[i, j]
initial(E[, ]) <- 0
initial(I[, ]) <- I0[i, j]
initial(R[, ]) <- 0
